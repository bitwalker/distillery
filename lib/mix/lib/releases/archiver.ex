defmodule Mix.Releases.Archiver do
  @moduledoc """
  This module is responsible for packaging a release into a tarball.
  """
  alias Mix.Releases.{Config, Overlays, Utils}

  def archive(%Config{} = config) do
    release = config.selected_release
    name = "#{release.name}"
    output_dir = Path.relative_to_cwd(Path.join("rel", "#{release.name}"))

    case make_tar(config, release, name, output_dir) do
      {:error, _} = err ->
        err
      :ok ->
        case apply_overlays(config, release, name, output_dir) do
          {:ok, overlays} ->
            update_tar(config, release, name, output_dir, overlays)
          {:error, _} = err ->
            err
        end
    end
  end

  defp make_tar(config, release, name, output_dir) do
    opts = [
      {:path, ['#{Path.join([output_dir, "lib", "*", "ebin"])}']},
      {:dirs, [:include | case config.include_src do
                          true  -> [:src, :c_src]
                          false -> []
                        end]},
      {:outdir, '#{Path.join([output_dir, "releases", release.version])}'} |
      case config.include_erts do
        true ->
          path = Path.expand("#{:code.root_dir()}")
          [{:erts, '#{path}'}]
        false ->
          []
        path ->
          path = Path.expand(path)
          [{:erts, '#{path}'}]
      end
    ]
    rel_path = '#{Path.join([output_dir, "releases", release.version, name])}'
    case :systools.make_tar(rel_path, opts) do
      :ok ->
        :ok
      {:ok, mod, warnings} ->
        {:error, {:tar_generation_warn, mod, warnings}}
      :error ->
        {:error, {:tar_generation_error, :unknown}}
      {:error, mod, errors} ->
        {:error, {:tar_generation_error, mod, errors}}
    end
  end

  defp update_tar(config, release, name, output_dir, overlays) do
    tarfile = '#{Path.join([output_dir, "releases", release.version, name <> ".tar.gz"])}'
    tmpdir = Utils.insecure_mkdtemp!
    :erl_tar.extract(tarfile, [{:cwd, '#{tmpdir}'}, :compressed])
    :ok = :erl_tar.create(tarfile, [
          {'releases', '#{Path.join(tmpdir, "releases")}'},
          {'#{Path.join("releases", "start_erl.data")}',
           '#{Path.join([output_dir, "releases", "start_erl.data"])}'},
          {'#{Path.join("releases", "RELEASES")}',
           '#{Path.join([output_dir, "releases", "RELEASES"])}'},
          {'#{Path.join(["releases", release.version, "vm.args"])}',
           '#{Path.join([output_dir, "releases", release.version, "vm.args"])}'},
          {'#{Path.join(["releases", release.version, "sys.config"])}',
           '#{Path.join([output_dir, "releases", release.version, "sys.config"])}'},
          {'#{Path.join(["releases", release.version, name <> ".sh"])}',
           '#{Path.join([output_dir, "releases", release.version, name <> ".sh"])}'},
          {'bin', '#{Path.join(output_dir, "bin")}'} |
          case config.include_erts do
            false ->
              case config.include_system_libs do
                false ->
                  libs = Path.wildcard(Path.join([tmpdir, "lib", "*"]))
                  system_libs = Path.wildcard(Path.join("#{:code.lib_dir}", "*"))
                  for libdir <- :lists.subtract(libs, system_libs),
                    do: {'#{Path.join("lib", libdir)}', '#{Path.join([tmpdir, "lib", libdir])}'}
                true ->
                  [{'lib', '#{Path.join(tmpdir, "lib")}'}]
              end
            true ->
              erts_vsn = Utils.erts_version()
              [{'lib', '#{Path.join(tmpdir, "lib")}'},
               {'erts-#{erts_vsn}', '#{Path.join(output_dir, "erts-" <> erts_vsn)}'}]
          end
        ] ++ overlays, [:dereference, :compressed])
    File.rm_rf!(tmpdir)
    :ok
  end

  defp apply_overlays(config, release, _name, output_dir) do
    overlay_vars = config.overlay_vars ++ generate_overlay_vars(config, release)
    hook_overlays = [
      {:mkdir, "releases/<%= release_version %>/hooks"},
      {:copy, config.pre_start_hook, "releases/<%= release_version %>/hooks/pre_start"},
      {:copy, config.post_start_hook, "releases/<%= release_version %>/hooks/post_start"},
      {:copy, config.pre_stop_hook, "releases/<%= release_version %>/hooks/pre_stop"},
      {:copy, config.post_stop_hook, "releases/<%= release_version %>/hooks/post_stop"}
    ] |> Enum.filter(fn {:copy, nil, _} -> false; _ -> true end)
    overlays = hook_overlays ++ config.overlays
    case Overlays.apply(release, output_dir, overlays, overlay_vars) do
      {:ok, paths} ->
        {:ok, Enum.map(paths, fn path ->
            {'#{path}', '#{Path.join([output_dir, path])}'}
          end)}
      {:error, _} = err ->
        err
    end
  end

  defp generate_overlay_vars(_config, release) do
    [erts_vsn: Utils.erts_version(),
     release_name: release.name,
     release_version: release.version]
  end
end
