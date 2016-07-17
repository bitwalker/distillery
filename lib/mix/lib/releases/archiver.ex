defmodule Mix.Releases.Archiver do
  @moduledoc """
  This module is responsible for packaging a release into a tarball.
  """
  alias Mix.Releases.{Release, Overlays, Utils, Logger}

  def archive(%Release{} = release) do
    name = "#{release.name}"
    output_dir = Path.relative_to_cwd(Path.join("rel", "#{release.name}"))

    Logger.debug "Archiving #{release.name}-#{release.version}"
    case make_tar(release, name, output_dir) do
      {:error, _} = err ->
        err
      :ok ->
        case apply_overlays(release, name, output_dir) do
          {:ok, overlays} ->
            update_tar(release, name, output_dir, overlays)
          {:error, _} = err ->
            err
        end
    end
  end

  defp make_tar(release, name, output_dir) do
    opts = [
      {:path, ['#{Path.join([output_dir, "lib", "*", "ebin"])}']},
      {:dirs, [:include | case release.profile.include_src do
                          true  -> [:src, :c_src]
                          false -> []
                        end]},
      {:outdir, '#{Path.join([output_dir, "releases", release.version])}'} |
      case release.profile.include_erts do
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
    Logger.debug "Writing tarball to #{rel_path}.tar.gz"
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

  defp update_tar(release, name, output_dir, overlays) do
    Logger.debug "Updating tarball"
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
          case release.profile.include_erts do
            false ->
              case release.profile.include_system_libs do
                false ->
                  Logger.debug "Stripping system libs from release tarball"
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
    Logger.debug "Tarball updated!"
    File.rm_rf!(tmpdir)
    :ok
  end

  defp apply_overlays(release, _name, output_dir) do
    Logger.debug "Applying overlays"
    overlay_vars = release.profile.overlay_vars ++ generate_overlay_vars(release)
    hook_overlays = [
      {:mkdir, "releases/<%= release_version %>/hooks"},
      {:copy, release.profile.pre_start_hook, "releases/<%= release_version %>/hooks/pre_start"},
      {:copy, release.profile.post_start_hook, "releases/<%= release_version %>/hooks/post_start"},
      {:copy, release.profile.pre_stop_hook, "releases/<%= release_version %>/hooks/pre_stop"},
      {:copy, release.profile.post_stop_hook, "releases/<%= release_version %>/hooks/post_stop"}
    ] |> Enum.filter(fn {:copy, nil, _} -> false; _ -> true end)
    overlays = hook_overlays ++ release.profile.overlays
    case Overlays.apply(release, output_dir, overlays, overlay_vars) do
      {:ok, paths} ->
        {:ok, Enum.map(paths, fn path ->
            {'#{path}', '#{Path.join([output_dir, path])}'}
          end)}
      {:error, _} = err ->
        err
    end
  end

  defp generate_overlay_vars(release) do
    vars = [erts_vsn: Utils.erts_version(),
            release_name: release.name,
            release_version: release.version]
    Logger.debug "Generated overlay vars:"
    IO.puts "#{IO.ANSI.cyan}  " <>
      "#{Enum.map(vars, fn {k,v} -> "#{k}=#{inspect v}" end) |> Enum.join("\n  ")}" <>
      IO.ANSI.reset
    vars
  end
end
