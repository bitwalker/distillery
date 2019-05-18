defmodule Distillery.Releases.Archiver do
  @moduledoc """
  This module is responsible for packaging a release into a tarball.
  """
  alias Distillery.Releases.Release
  alias Distillery.Releases.Utils
  alias Distillery.Releases.Shell
  alias Distillery.Releases.Plugin
  alias Distillery.Releases.Archiver.Archive

  @doc """
  Given an assembled release, and the Release struct representing it,
  this function will package up the release into a tar.gz file.

  It returns `{:ok, "path/to/tarball"}`, or `{:error, reason}`
  """
  @spec archive(Release.t()) :: {:ok, String.t()} | {:error, term}
  def archive(%Release{} = release) do
    Shell.debug("Archiving #{release.name}-#{release.version}")

    with {:ok, release} <- Plugin.before_package(release),
         :ok <- make_tar(release),
         {:ok, tarfile} <- update_tar(release),
         {:ok, _} <- Plugin.after_package(release) do
      cond do
        Release.executable?(release) ->
          Shell.debug("Generating executable..")
          binfile = Release.archive_path(release)

          with {:ok, tar} <- File.read(tarfile),
               :ok <- File.rm(tarfile),
               {:ok, header} <-
                 Utils.template(
                   :executable_header,
                   release_name: release.name,
                   executable_options: release.profile.executable
                 ),
               executable = <<header::binary, tar::binary>>,
               :ok <- File.write(binfile, executable),
               :ok <- File.chmod(binfile, 0o744) do
            {:ok, tarfile}
          else
            {:error, {:template, _}} = err -> err
            {:error, reason} -> {:error, {:executable, :file, reason}}
          end

        :else ->
          {:ok, tarfile}
      end
    end
  end

  # Constructs initial release tarball using systools
  defp make_tar(release) do
    archive_path =
      Release.archive_path(%{release | :profile => %{release.profile | :executable => false}})

    included_dirs =
      if release.profile.include_src do
        [:include, :src, :c_src, :lib]
      else
        [:include]
      end

    erts_opt =
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

    opts = [
      :silent,
      {:path, ['#{Path.join([release.profile.output_dir, "lib", "*", "ebin"])}']},
      {:dirs, included_dirs},
      {:outdir, '#{Path.dirname(archive_path)}'} | erts_opt
    ]

    rel_path = '#{String.trim_trailing(archive_path, ".tar.gz")}'
    Shell.debug("Writing archive to #{rel_path}.tar.gz")

    case :systools.make_tar(rel_path, opts) do
      :ok ->
        :ok

      {:ok, _mod, []} ->
        :ok

      {:ok, mod, warnings} ->
        {:error, {:tar_generation_warn, mod, warnings}}

      :error ->
        {:error, {:tar_generation_error, :unknown}}

      {:error, mod, errors} ->
        {:error, {:tar_generation_error, mod, errors}}
    end
  end

  # Applies overlays and adds extra files to release tarball and recreates it
  defp update_tar(%Release{name: name, version: version} = release) do
    output_dir = release.profile.output_dir
    Shell.debug("Updating archive..")

    initial_tar_path = Path.join([output_dir, "releases", version, "#{name}.tar.gz"])

    with {:ok, tmpdir} <- Utils.insecure_mkdir_temp(),
         {:ok, _} <- Archive.extract(initial_tar_path, tmpdir),
         archive = make_archive(release, tmpdir),
         {:ok, archive_path} <- save_archive(release, archive),
         _ <- File.rm_rf(tmpdir) do
      {:ok, archive_path}
    else
      {:error, reason, file} ->
        {:error, {:archiver, {:file, reason, file}}}

      {:error, _} = err ->
        err
    end
  catch
    kind, err ->
      {:error, {:archiver, Exception.normalize(kind, err, System.stacktrace())}}
  end

  defp make_archive(%Release{version: version} = release, tmpdir) do
    name = "#{release.name}"
    output_dir = release.profile.output_dir

    archive =
      Archive.new(name, output_dir)
      |> Archive.add(Path.join(tmpdir, "releases"), "releases")
      |> Archive.add(Path.join([output_dir, "bin"]))
      |> Archive.add(Path.join([output_dir, "releases", "start_erl.data"]))
      |> Archive.add(Path.join([output_dir, "releases", "RELEASES"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "vm.args"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "sys.config"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "start.boot"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "start_clean.boot"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "start_clean.script"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "no_dot_erlang.boot"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "no_dot_erlang.script"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "config.boot"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "config.script"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "#{name}.sh"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "#{name}.ps1"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "#{name}.boot"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "#{name}.script"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "#{name}.rel"]))
      |> Archive.add(Path.join([output_dir, "releases", version, "libexec"]))

    consolidation_path = Path.join([output_dir, "lib", "#{name}-#{version}", "consolidated"])

    archive =
      if File.exists?(consolidation_path) do
        Archive.add(archive, consolidation_path)
      else
        archive
      end

    # Only attempt to add relup file if this is an upgrade
    archive =
      if release.is_upgrade do
        Archive.add(archive, Path.join([output_dir, "releases", version, "relup"]))
      else
        archive
      end

    # Handle optional libs and runtime
    archive =
      archive
      |> maybe_include_erts(release, tmpdir)
      |> maybe_include_system_libs(release, tmpdir)

    # Apply overlays
    Enum.reduce(release.resolved_overlays, archive, fn {entry, source}, acc ->
      Archive.add(acc, source, entry)
    end)
  end

  defp maybe_include_erts(archive, %Release{profile: %{include_erts: false}}, _tmpdir) do
    archive
  end

  defp maybe_include_erts(archive, %Release{profile: %{include_erts: true}} = release, tmpdir) do
    erts_vsn = Utils.erts_version()

    archive
    |> Archive.add(Path.join(tmpdir, "lib"), "lib")
    |> Archive.add(Path.join(release.profile.output_dir, "erts-#{erts_vsn}"), "erts-#{erts_vsn}")
  end

  defp maybe_include_erts(archive, %Release{profile: %{include_erts: path}} = release, tmpdir) do
    {:ok, erts_vsn} = Utils.detect_erts_version(path)

    archive
    |> Archive.add(Path.join(tmpdir, "lib"), "lib")
    |> Archive.add(Path.join(release.profile.output_dir, "erts-#{erts_vsn}"))
  end

  defp maybe_include_system_libs(archive, %Release{profile: %{include_erts: false}}, tmpdir) do
    Shell.debug("Stripping system libs from release archive since ERTS is not included")

    # The set of all libs required for this release
    lib_path = Path.join([tmpdir, "lib", "*"])

    libs =
      lib_path
      |> Path.wildcard()
      |> Enum.map(&Path.basename/1)
      |> MapSet.new()

    # Applications belonging to the Erlang system
    system_lib_path = Path.join("#{:code.lib_dir()}", "*")

    system_libs =
      system_lib_path
      |> Path.wildcard()
      |> Enum.map(&Path.basename/1)
      |> MapSet.new()

    # Remove the set of system libs from the set of all libs
    # and add only those remaining to the archive
    libs
    |> MapSet.difference(system_libs)
    |> MapSet.to_list()
    |> Enum.reduce(archive, fn lib, acc ->
      Archive.add(acc, Path.join([tmpdir, "lib", lib]), Path.join("lib", lib))
    end)
  end

  defp maybe_include_system_libs(archive, %Release{profile: %{include_erts: _}}, tmpdir) do
    Shell.debug("Including system libs from configured Erlang installation")
    Archive.add(archive, Path.join(tmpdir, "lib"), "lib")
  end

  defp save_archive(%Release{version: version, profile: %{output_dir: output_dir}}, archive) do
    Shell.debug("Saving archive..")
    target_dir = Path.join([output_dir, "releases", version])

    case Archive.save(archive, target_dir) do
      {:ok, _archive_path} = result ->
        Shell.debug("Archive saved!")
        result

      {:error, reason} ->
        {:error, {:archiver, {:erl_tar, reason}}}
    end
  end
end
