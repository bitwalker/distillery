defmodule Mix.Releases.Archiver do
  @moduledoc """
  This module is responsible for packaging a release into a tarball.
  """
  alias Mix.Releases.{Release, Utils, Logger, Plugin, Profile}

  @doc """
  Given an assembled release, and the Release struct representing it,
  this function will package up the release into a tar.gz file,
  applying any overlays it contains prior to doing so.

  It returns `{:ok, "path/to/tarball"}`, or `{:error, reason}`
  """
  @spec archive(Release.t) :: {:ok, String.t} | {:error, term}
  def archive(%Release{} = release) do
    Logger.debug "Archiving #{release.name}-#{release.version}"
    with {:ok, release}  <- Plugin.before_package(release),
         :ok             <- make_tar(release),
         {:ok, tarfile}  <- update_tar(release),
         {:ok, _}        <- Plugin.after_package(release),
       do: {:ok, tarfile}
  end

  defp make_tar(release) do
    name = "#{release.name}"
    opts = [
      {:path, ['#{Path.join([release.output_dir, "lib", "*", "ebin"])}']},
      {:dirs, [:include | case release.profile.include_src do
                          true  -> [:src, :c_src]
                          false -> []
                        end]},
      {:outdir, '#{Path.join([release.output_dir, "releases", release.version])}'} |
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
    rel_path = '#{Path.join([release.output_dir, "releases", release.version, name])}'
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

  defp update_tar(release) do
    Logger.debug "Updating tarball"
    overlays   = release.resolved_overlays
    name       = "#{release.name}"
    output_dir = release.output_dir
    tarfile    = '#{Path.join([output_dir, "releases", release.version, name <> ".tar.gz"])}'
    with {:ok, tmpdir} <- Utils.insecure_mkdir_temp(),
         :ok <- :erl_tar.extract(tarfile, [{:cwd, '#{tmpdir}'}, :compressed]),
         :ok <- strip_release(release, tmpdir),
         :ok <- :erl_tar.create(tarfile, [
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
              ] ++ overlays, [:dereference, :compressed]),
        :ok      <- Logger.debug("Tarball updated!"),
        {:ok, _} <-  File.rm_rf(tmpdir) do
      {:ok, tarfile}
    else
      {:error, reason} ->
        {:error, "Failed to create temporary directory `#{inspect reason}`"}
      {:error, reason, file} ->
        {:error, "Failed to remove #{file} (#{inspect reason})"}
    end
  end

  # Strips debug info from the release, if so configured
  defp strip_release(%Release{profile: %Profile{strip_debug_info: true, dev_mode: false}}, strip_path) do
    Logger.debug "Stripping release (#{strip_path})"
    case :beam_lib.strip_release(String.to_charlist(strip_path)) do
      {:ok, _} ->
        :ok
      {:error, :beam_lib, reason} ->
        {:error, "failed to strip release: #{inspect reason}"}
    end
  end
  defp strip_release(_, _), do: :ok

end
