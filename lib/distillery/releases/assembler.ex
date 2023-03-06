defmodule Distillery.Releases.Assembler do
  @moduledoc """
  This module is responsible for assembling a release based on a `Distillery.Releases.Config`
  struct. It creates the release directory, copies applications, and generates release-specific
  files required by `:systools` and `:release_handler`.
  """
  alias Distillery.Releases.Config
  alias Distillery.Releases.Release
  alias Distillery.Releases.Environment
  alias Distillery.Releases.Profile
  alias Distillery.Releases.BootScript
  alias Distillery.Releases.Utils
  alias Distillery.Releases.Shell
  alias Distillery.Releases.Appup
  alias Distillery.Releases.Plugin
  alias Distillery.Releases.Overlays

  require Record
  Record.defrecordp(:file_info, Record.extract(:file_info, from_lib: "kernel/include/file.hrl"))

  @doc false
  @spec pre_assemble(Config.t()) :: {:ok, Release.t()} | {:error, term}
  def pre_assemble(%Config{} = config) do
    with {:ok, environment} <- Release.select_environment(config),
         {:ok, release} <- Release.select_release(config),
         release <- apply_environment(release, environment),
         {:ok, release} <- Plugin.before_assembly(release),
         {:ok, release} <- Release.apply_configuration(release, config, true),
         :ok <- Release.validate(release),
         :ok <- make_paths(release) do
      {:ok, release}
    end
  end

  @doc """
  This function takes a Config struct and assembles the release.

  **Note: This operation has side-effects!** It creates files, directories,
  copies files from other filesystem locations. If failures occur, no cleanup
  of files/directories is performed. However, all files/directories created by
  this function are scoped to the current project's `rel` directory, and cannot
  impact the filesystem outside of this directory.
  """
  @spec assemble(Config.t()) :: {:ok, Release.t()} | {:error, term}
  def assemble(%Config{} = config) do
    with {:ok, release} <- pre_assemble(config),
         {:ok, release} <- generate_overlay_vars(release),
         {:ok, release} <- copy_applications(release),
         :ok <- write_release_metadata(release),
         :ok <- write_release_scripts(release),
         {:ok, release} <- apply_overlays(release),
         :ok <- strip_release(release),
         {:ok, release} <- Plugin.after_assembly(release),
         do: {:ok, release}
  end

  # Applies the environment profile to the release profile.
  @spec apply_environment(Release.t(), Environment.t()) :: Release.t()
  def apply_environment(%Release{} = r, %Environment{} = e) do
    Shell.info("Building release #{r.name}:#{r.version} using environment #{e.name}")
    Release.apply_environment(r, e)
  end

  # Copies application beams to the output directory
  defp copy_applications(%Release{profile: %Profile{output_dir: output_dir}} = release) do
    Shell.debug("Copying applications to #{output_dir}")

    copy_applications(release, release.applications)

    case copy_consolidated(release) do
      :ok ->
        {:ok, release}

      {:error, _} = err ->
        err
    end
  catch
    :throw, {:error, _reason} = err ->
      err
  end

  defp copy_applications(_release, []), do: :ok

  defp copy_applications(release, [app | apps]) do
    case copy_app(app, release) do
      :ok ->
        copy_applications(release, apps)

      {:error, _} = err ->
        throw(err)
    end
  end

  # Copy consolidated .beams
  defp copy_consolidated(%Release{profile: %Profile{dev_mode: true}}) do
    :ok
  end

  defp copy_consolidated(%Release{name: name, version: version} = release) do
    src = Mix.Project.consolidation_path()
    dest = Path.join([Release.lib_path(release), "#{name}-#{version}", "consolidated"])
    Utils.remove_symlink_or_dir!(dest)
    File.mkdir_p!(dest)

    if File.exists?(src) do
      case File.cp_r(src, dest) do
        {:ok, _} ->
          :ok

        {:error, reason, file} ->
          {:error, {:assembler, :file, {:copy_consolidated, file, reason}}}
      end
    else
      :ok
    end
  end

  # Copies a specific application to the output directory
  defp copy_app(app, %Release{} = rel) do
    include_src? = rel.profile.include_src
    include_erts? = rel.profile.include_erts

    dev_mode? =
      if Release.executable?(rel) do
        false
      else
        rel.profile.dev_mode
      end

    app_name = app.name
    app_version = app.vsn
    app_dir = app.path
    lib_dir = Release.lib_path(rel)
    target_dir = Path.join(lib_dir, "#{app_name}-#{app_version}")
    Utils.remove_symlink_or_dir!(target_dir)

    case include_erts? do
      true ->
        copy_app(app_name, app_dir, target_dir, dev_mode?, include_src?)

      p when is_binary(p) ->
        app_dir =
          if Utils.is_erts_lib?(app_dir) do
            Path.join([p, "lib", "#{app_name}-#{app_version}"])
          else
            app_dir
          end

        copy_app(app_name, app_dir, target_dir, dev_mode?, include_src?)

      _ ->
        case Utils.is_erts_lib?(app_dir) do
          true ->
            :ok

          false ->
            copy_app(app_name, app_dir, target_dir, dev_mode?, include_src?)
        end
    end
  end

  defp copy_app(_app_name, app_dir, target_dir, true, _include_src?) do
    case File.ln_s(app_dir, target_dir) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, {:assembler, :file, {:copy_app, app_dir, target_dir, reason}}}
    end
  end

  defp copy_app(app_name, app_dir, target_dir, false, include_src?) do
    case File.mkdir_p(target_dir) do
      {:error, reason} ->
        {:error, {:assembler, :file, {:copy_app, target_dir, reason}}}

      :ok ->
        valid_dirs =
          cond do
            include_src? ->
              ["ebin", "include", "priv", "lib", "src"]

            :else ->
              ["ebin", "include", "priv"]
          end

        extra_source_dirs = project_app_src_dirs(app_name)

        (Path.wildcard(Path.join(app_dir, "*")) ++ extra_source_dirs)
        |> Enum.filter(fn p -> Path.basename(p) in valid_dirs end)
        |> Enum.each(fn p ->
          t = Path.join(target_dir, Path.basename(p))

          if Utils.symlink?(p) do
            # We need to follow the symlink
            File.mkdir_p!(t)

            Path.wildcard(Path.join(p, "*"))
            |> Enum.each(fn child ->
              tc = Path.join(t, Path.basename(child))

              case File.cp_r(child, tc) do
                {:ok, _} ->
                  :ok

                {:error, reason, file} ->
                  throw({:error, {:assembler, :file, {reason, file}}})
              end
            end)
          else
            case File.cp_r(p, t) do
              {:ok, _} ->
                :ok

              {:error, reason, file} ->
                throw({:error, {:assembler, :file, {reason, file}}})
            end
          end
        end)
    end
  rescue
    e in [File.Error] ->
      {:error, {:assembler, {e, System.stacktrace()}}}
  catch
    :error, {:assembler, _mod, _reason} = err ->
      {:error, err}
  end

  # Finds sources for `app_name`. This is used for applications built from
  # this project, where the source code lies in a different location than the
  # compiled files.
  defp project_app_src_dirs(app_name) do
    case project_app_src_root(app_name) do
      nil -> []
      path -> Path.wildcard(Path.join(path, "{lib,src}"))
    end
  end

  # Returns a path of the source code directory for an application built from
  # this project.
  defp project_app_src_root(app_name) do
    if not Mix.Project.umbrella?() && Mix.Project.get().project[:app] == app_name do
      # This is a top-level application.
      File.cwd!()
    else
      # This returns a directory if the app is either a dependency or an
      # application in umbrella. It returns `nil` otherwise.
      Map.get(Mix.Project.deps_paths(), app_name)
    end
  end

  # Creates release metadata files
  defp write_release_metadata(%Release{name: name} = release) do
    resource_path =
      release
      |> Release.version_path()
      |> Path.join("#{name}.rel")

    with :ok <- Utils.write_term(resource_path, Release.to_resource(release)),
         :ok <- generate_relup(release) do
      :ok
    end
  end

  # Creates the .boot files, config files (vm.args, sys.config, config.exs),
  # start_erl.data, release_rc scripts, and includes ERTS into
  # the release if so configured
  defp write_release_scripts(%Release{} = release) do
    name = "#{release.name}"
    rel_dir = Release.version_path(release)
    bin_dir = Path.join(release.profile.output_dir, "bin")
    template_params = release.profile.overlay_vars

    scripts = [
      {Path.join(bin_dir, name), {:template, :release_rc_entry, template_params}, 0o777},
      {Path.join(bin_dir, "#{name}_rc_exec.sh"), {:template, :release_rc_exec, template_params},
       0o777},
      {Path.join(rel_dir, "#{name}.sh"), {:template, :release_rc_main, template_params}, 0o777},
      {Path.join(bin_dir, "#{name}.bat"), {:template, :release_rc_win_exec, template_params},
       0o777},
      {Path.join(rel_dir, "#{name}.ps1"), {:template, "release_rc_win_main.ps1", template_params},
       0o777}
    ]

    with :ok <- Utils.write_all(scripts),
         :ok <- generate_start_erl_data(release),
         :ok <- generate_vm_args(release),
         :ok <- generate_sys_config(release),
         :ok <- include_erts(release),
         :ok <- make_boot_scripts(release) do
      :ok
    else
      {:error, reason, file} ->
        {:error, {:assembler, :file, {reason, file}}}

      {:error, r} = err when is_tuple(r) and elem(r, 0) == :assembler ->
        err

      {:error, reason} ->
        {:error, {:assembler, reason}}
    end
  end

  # Generates a relup and .appup for all upgraded applications during upgrade releases
  defp generate_relup(%Release{is_upgrade: false}), do: :ok

  defp generate_relup(%Release{name: name, upgrade_from: upfrom} = release) do
    rel_dir = Release.version_path(release)
    output_dir = release.profile.output_dir

    Shell.debug("Generating relup for #{name}")

    v1_rel = Path.join([output_dir, "releases", upfrom, "#{name}.rel"])
    v2_rel = Path.join(rel_dir, "#{name}.rel")

    case {File.exists?(v1_rel), File.exists?(v2_rel)} do
      {false, true} ->
        {:error, {:assembler, {:missing_rel, name, upfrom, v1_rel}}}

      {true, false} ->
        {:error, {:assembler, {:missing_rel, name, release.version, v2_rel}}}

      {false, false} ->
        {:error, {:assembler, {:missing_rels, name, upfrom, release.version, v1_rel, v2_rel}}}

      {true, true} ->
        v1_apps = extract_relfile_apps(v1_rel)
        v2_apps = extract_relfile_apps(v2_rel)
        changed = get_changed_apps(v1_apps, v2_apps)
        added = get_added_apps(v2_apps, changed)
        removed = get_removed_apps(v1_apps, v2_apps)

        case generate_appups(release, changed, output_dir) do
          {:error, _} = err ->
            err

          :ok ->
            current_rel = Path.join([output_dir, "releases", release.version, "#{name}"])
            upfrom_rel = Path.join([output_dir, "releases", release.upgrade_from, "#{name}"])

            result =
              :systools.make_relup(
                String.to_charlist(current_rel),
                [String.to_charlist(upfrom_rel)],
                [String.to_charlist(upfrom_rel)],
                [
                  {:outdir, String.to_charlist(rel_dir)},
                  {:path, get_relup_code_paths(added, changed, removed, output_dir)},
                  :silent,
                  :no_warn_sasl
                ]
              )

            case result do
              {:ok, relup, _mod, []} ->
                Shell.info("Relup successfully created")
                Utils.write_term(Path.join(rel_dir, "relup"), relup)

              {:ok, relup, mod, warnings} ->
                Shell.warn(Utils.format_systools_warning(mod, warnings))
                Shell.info("Relup successfully created")
                Utils.write_term(Path.join(rel_dir, "relup"), relup)

              {:error, mod, errors} ->
                error = Utils.format_systools_error(mod, errors)
                {:error, {:assembler, error}}
            end
        end
    end
  end

  # Get a list of applications from the .rel file at the given path
  @spec extract_relfile_apps(String.t()) :: [{atom, charlist}] | no_return
  defp extract_relfile_apps(path) when is_binary(path) do
    case Utils.read_terms(path) do
      {:error, _} = err ->
        throw(err)

      {:ok, [{:release, _rel, _erts, apps}]} ->
        Enum.map(apps, fn
          {a, v} -> {a, v}
          {a, v, _start_type} -> {a, v}
        end)

      {:ok, other} ->
        throw({:error, {:assembler, {:malformed_relfile, path, other}}})
    end
  end

  # Determine the set of apps which have changed between two versions
  defp get_changed_apps(a, b) do
    as = Enum.map(a, fn app -> elem(app, 0) end) |> MapSet.new()
    bs = Enum.map(b, fn app -> elem(app, 0) end) |> MapSet.new()
    shared = MapSet.to_list(MapSet.intersection(as, bs))
    a_versions = Enum.map(shared, fn n -> {n, elem(List.keyfind(a, n, 0), 1)} end) |> MapSet.new()
    b_versions = Enum.map(shared, fn n -> {n, elem(List.keyfind(b, n, 0), 1)} end) |> MapSet.new()

    MapSet.difference(b_versions, a_versions)
    |> MapSet.to_list()
    |> Enum.map(fn {n, v2} ->
      v1 = List.keyfind(a, n, 0) |> elem(1)
      {n, "#{v1}", "#{v2}"}
    end)
  end

  # Determine the set of apps which were added between two versions
  defp get_added_apps(v2_apps, changed) do
    changed_apps = Enum.map(changed, &elem(&1, 0))

    Enum.reject(v2_apps, fn a ->
      elem(a, 0) in changed_apps
    end)
  end

  # Determine the set of apps removed from v1 to v2
  defp get_removed_apps(a, b) do
    as = Enum.map(a, fn app -> elem(app, 0) end) |> MapSet.new()
    bs = Enum.map(b, fn app -> elem(app, 0) end) |> MapSet.new()

    MapSet.difference(as, bs)
    |> MapSet.to_list()
    |> Enum.map(fn n -> {n, elem(List.keyfind(a, n, 0), 1)} end)
  end

  # Generate .appup files for a list of {app, v1, v2}
  defp generate_appups(_rel, [], _output_dir), do: :ok

  defp generate_appups(release, [{app, v1, v2} | apps], output_dir) do
    v1_path = Path.join([output_dir, "lib", "#{app}-#{v1}"])
    v2_path = Path.join([output_dir, "lib", "#{app}-#{v2}"])
    target_appup_path = Path.join([v2_path, "ebin", "#{app}.appup"])

    appup_path =
      case Appup.locate(app, v1, v2) do
        nil ->
          target_appup_path

        path ->
          File.cp!(path, target_appup_path)
      end

    # Check for existence
    appup_exists? = File.exists?(target_appup_path)

    appup_valid? =
      if appup_exists? do
        case Utils.read_terms(target_appup_path) do
          {:ok, [{v2p, [{v1p, _}], [{v1p, _}]}]} ->
            cond do
              is_binary(v2p) and is_binary(v1p) ->
                # Versions are regular expressions
                v1p = Regex.compile!(v1p)
                v2p = Regex.compile!(v2p)
                String.match?(v1, v1p) and String.match?(v2, v2p)

              v2p == ~c[#{v2}] and v1p == ~c[#{v1}] ->
                true

              :else ->
                false
            end

          _other ->
            false
        end
      else
        false
      end

    cond do
      appup_exists? && appup_valid? ->
        Shell.debug("#{app} requires an appup, and one was provided, skipping generation..")
        generate_appups(release, apps, output_dir)

      appup_exists? ->
        Shell.warn(
          "#{app} has an appup file, but it is invalid for this release,\n" <>
            "    Backing up appfile with .bak extension and generating new one.."
        )

        :ok = File.cp!(target_appup_path, "#{appup_path}.bak")

        case Appup.make(app, v1, v2, v1_path, v2_path, release.profile.appup_transforms) do
          {:error, _} = err ->
            err

          {:ok, appup} ->
            :ok = Utils.write_term(target_appup_path, appup)
            Shell.info("Generated .appup for #{app} #{v1} -> #{v2}")
            generate_appups(release, apps, output_dir)
        end

      :else ->
        Shell.debug(
          "#{app} requires an appup, but it wasn't provided, one will be generated for you.."
        )

        case Appup.make(app, v1, v2, v1_path, v2_path, release.profile.appup_transforms) do
          {:error, _} = err ->
            err

          {:ok, appup} ->
            :ok = Utils.write_term(target_appup_path, appup)
            Shell.info("Generated .appup for #{app} #{v1} -> #{v2}")
            generate_appups(release, apps, output_dir)
        end
    end
  end

  # Get a list of code paths containing only those paths which have beams
  # from the two versions in the release being upgraded
  defp get_relup_code_paths(added, changed, removed, output_dir) do
    added_paths = get_added_relup_code_paths(added, output_dir, [])
    changed_paths = get_changed_relup_code_paths(changed, output_dir, [], [])
    removed_paths = get_removed_relup_code_paths(removed, output_dir, [])
    added_paths ++ changed_paths ++ removed_paths
  end

  defp get_changed_relup_code_paths([], _output_dir, v1_paths, v2_paths) do
    v2_paths ++ v1_paths
  end

  defp get_changed_relup_code_paths([{app, v1, v2} | apps], output_dir, v1_paths, v2_paths) do
    v1_path = Path.join([output_dir, "lib", "#{app}-#{v1}", "ebin"]) |> String.to_charlist()
    v2_path = Path.join([output_dir, "lib", "#{app}-#{v2}", "ebin"]) |> String.to_charlist()

    v2_path_consolidated =
      Path.join([output_dir, "lib", "#{app}-#{v2}", "consolidated"]) |> String.to_charlist()

    get_changed_relup_code_paths(apps, output_dir, [v1_path | v1_paths], [
      v2_path_consolidated,
      v2_path | v2_paths
    ])
  end

  defp get_added_relup_code_paths([], _output_dir, paths), do: paths

  defp get_added_relup_code_paths([{app, v2} | apps], output_dir, paths) do
    v2_path = Path.join([output_dir, "lib", "#{app}-#{v2}", "ebin"]) |> String.to_charlist()

    v2_path_consolidated =
      Path.join([output_dir, "lib", "#{app}-#{v2}", "consolidated"]) |> String.to_charlist()

    get_added_relup_code_paths(apps, output_dir, [v2_path_consolidated, v2_path | paths])
  end

  defp get_removed_relup_code_paths([], _output_dir, paths), do: paths

  defp get_removed_relup_code_paths([{app, v1} | apps], output_dir, paths) do
    v1_path = Path.join([output_dir, "lib", "#{app}-#{v1}", "ebin"]) |> String.to_charlist()

    v1_path_consolidated =
      Path.join([output_dir, "lib", "#{app}-#{v1}", "consolidated"]) |> String.to_charlist()

    get_removed_relup_code_paths(apps, output_dir, [v1_path_consolidated, v1_path | paths])
  end

  # Generates start_erl.data
  defp generate_start_erl_data(%Release{profile: %{include_erts: false}} = rel) do
    Shell.debug("Generating start_erl.data")
    version = rel.version
    contents = "ERTS_VSN #{version}"
    File.write(Path.join([Release.version_path(rel), "..", "start_erl.data"]), contents)
  end

  defp generate_start_erl_data(%Release{profile: %Profile{erts_version: erts}} = release) do
    Shell.debug("Generating start_erl.data")

    contents = "#{erts} #{release.version}"
    File.write(Path.join([Release.version_path(release), "..", "start_erl.data"]), contents)
  end

  # Generates vm.args
  defp generate_vm_args(%Release{profile: %Profile{vm_args: nil}} = rel) do
    Shell.debug("Generating vm.args")
    rel_dir = Release.version_path(rel)
    overlay_vars = rel.profile.overlay_vars

    with {:ok, contents} <- Utils.template("vm.args", overlay_vars),
         :ok <- File.write(Path.join(rel_dir, "vm.args"), contents) do
      :ok
    else
      {:error, {:template, _}} = err ->
        err

      {:error, reason} ->
        {:error, {:assembler, :file, reason}}
    end
  end

  defp generate_vm_args(%Release{profile: %Profile{vm_args: path}} = rel) do
    Shell.debug("Generating vm.args from #{Path.relative_to_cwd(path)}")
    path = Path.expand(path)
    rel_dir = Release.version_path(rel)
    overlay_vars = rel.profile.overlay_vars

    with {:ok, path} <- Overlays.template_str(path, overlay_vars),
         {:ok, templated} <- Overlays.template_file(path, overlay_vars),
         :ok <- File.write(Path.join(rel_dir, "vm.args"), templated) do
      :ok
    else
      {:error, {:template, _}} = err ->
        err

      {:error, {:template_str, _}} = err ->
        err

      {:error, reason} ->
        {:error, {:assembler, :file, reason}}
    end
  end

  # Generated when Mix.Config provider is active, default + provided sys.config
  defp generate_sys_config(%Release{profile: %Profile{} = profile} = rel) do
    overlay_vars = profile.overlay_vars
    config_exs_path = profile.config

    # Construct path to provided sys.config, if one was provided
    sys_config_path =
      case profile.sys_config do
        nil ->
          Shell.debug("Generating sys.config from #{Path.relative_to_cwd(config_exs_path)}")
          nil

        p when is_binary(p) ->
          case Overlays.template_str(p, overlay_vars) do
            {:ok, p} ->
              relative_config_exs_path = Path.relative_to_cwd(config_exs_path)
              relative_p = Path.relative_to_cwd(p)

              Shell.debug(
                "Generating sys.config from #{relative_config_exs_path} and #{relative_p}"
              )

              p

            {:error, _} = err ->
              throw(err)
          end
      end

    # Generate base sys.config from Mix config file
    base_config =
      config_exs_path
      |> generate_base_config(profile.config_providers)

    # If sys.config was provided, template it and merge over base config
    sys_config =
      case sys_config_path do
        nil ->
          base_config

        _ ->
          with {:ok, templated} <- Overlays.template_file(sys_config_path, overlay_vars),
               {:ok, tokens, _} <- :erl_scan.string(String.to_charlist(templated)),
               {:ok, sys_config} <- :erl_parse.parse_term(tokens),
               :ok <- validate_sys_config(sys_config),
               merged <- Mix.Config.merge(base_config, sys_config) do
            merged
          else
            err ->
              throw(err)
          end
      end

    # Append any included configs to generated sys.config
    sys_config = append_included_configs(sys_config, profile.included_configs)

    # Write result
    Utils.write_term(Path.join(Release.version_path(rel), "sys.config"), sys_config)
  catch
    :throw, {:error, {:template, _}} = err ->
      err

    :throw, {:error, {:template_str, _}} = err ->
      err

    :throw, {:error, {:assembler, _}} = err ->
      err

    :throw, {:error, error_info, _end_loc} when is_tuple(error_info) ->
      {:error, {:assembler, {:invalid_sys_config, error_info}}}

    :throw, {:error, error_info} when is_tuple(error_info) ->
      {:error, {:assembler, {:invalid_sys_config, error_info}}}
  end

  defp generate_base_config(base_config_path, config_providers) do
    config = Distillery.Releases.Config.Providers.Elixir.eval!(base_config_path)

    config =
      case Keyword.get(config, :sasl) do
        nil ->
          put_in(config, [:sasl], errlog_type: :error, sasl_error_logger: false)

        sasl ->
          config
          |> put_in([:sasl, :sasl_error_logger], Keyword.get(sasl, :sasl_error_logger, false))
          |> put_in([:sasl, :errlog_type], Keyword.get(sasl, :errlog_type, :error))
      end

    case Keyword.get(config, :distillery) do
      nil ->
        Keyword.put(config, :distillery, config_providers: config_providers)

      dc ->
        Keyword.put(config, :distillery, Keyword.merge(dc, config_providers: config_providers))
    end
  end

  # Extend the config with the paths of additional config files
  defp append_included_configs(config, []), do: config

  defp append_included_configs(config, configs) when is_list(configs) do
    included_configs = Enum.map(configs, &String.to_charlist/1)
    config ++ included_configs
  end

  defp validate_sys_config(sys_config) when is_list(sys_config) do
    cond do
      Keyword.keyword?(sys_config) ->
        is_config? =
          Enum.reduce(sys_config, true, fn
            {app, config}, acc when is_atom(app) and is_list(config) ->
              acc && Keyword.keyword?(config)

            {_app, _config}, _acc ->
              false
          end)

        cond do
          is_config? ->
            :ok

          :else ->
            {:error, {:assembler, {:invalid_sys_config, :invalid_terms}}}
        end

      :else ->
        {:error, {:assembler, {:invalid_sys_config, :invalid_terms}}}
    end
  end

  defp validate_sys_config(_sys_config),
    do: {:error, {:assembler, {:invalid_sys_config, :invalid_terms}}}

  # Adds ERTS to the release, if so configured
  defp include_erts(%Release{profile: %Profile{include_erts: false}, is_upgrade: false}), do: :ok

  defp include_erts(%Release{profile: %Profile{include_erts: false}, is_upgrade: true}) do
    {:error, {:assembler, :erts_missing_for_upgrades}}
  end

  defp include_erts(%Release{} = release) do
    include_erts = release.profile.include_erts
    output_dir = release.profile.output_dir

    prefix =
      case include_erts do
        true ->
          "#{:code.root_dir()}"

        p when is_binary(p) ->
          Path.expand(p)
      end

    erts_vsn = release.profile.erts_version
    erts_dir = Path.join([prefix, "erts-#{erts_vsn}"])

    Shell.info("Including ERTS #{erts_vsn} from #{Path.relative_to_cwd(erts_dir)}")

    erts_output_dir = Path.join(output_dir, "erts-#{erts_vsn}")
    erl_path = Path.join([erts_output_dir, "bin", "erl"])
    erl_ini_file = Path.join([erts_output_dir, "bin", "erl.ini"])

    with :ok <- Utils.remove_if_exists(erts_output_dir),
         :ok <- File.mkdir_p(erts_output_dir),
         {:ok, _} <- File.cp_r(erts_dir, erts_output_dir),
         {:ok, _} <- File.rm_rf(erl_ini_file),
         {:ok, _} <- File.rm_rf(erl_path),
         {:ok, erl_script} <- Utils.template(:erl_script, release.profile.overlay_vars),
         :ok <- File.write(erl_path, erl_script),
         :ok <- File.chmod(erl_path, 0o755) do
      :ok
    else
      {:error, reason} ->
        {:error, {:assembler, :file, {:include_erts, reason}}}

      {:error, reason, file} ->
        {:error, {:assembler, :file, {:include_erts, reason, file}}}
    end
  end

  # Generates .boot script
  defp make_boot_scripts(%Release{name: name, profile: profile} = release) do
    Shell.debug("Generating boot scripts")

    output_dir = profile.output_dir

    with {:ok, boot} <- BootScript.new(release) do
      # This boot script contains all applications, only starting the minimal set
      clean_boot =
        boot
        |> BootScript.start_only([:kernel, :stdlib, :compiler, :elixir])

      # The config boot is like the clean boot, but executes all config providers once started
      providers = release.profile.config_providers

      config_boot =
        clean_boot
        |> BootScript.after_started(:elixir, [
          {:apply, {Distillery.Releases.Config.Provider, :init, [providers]}}
        ])

      # Finally, this is the "real" boot script for the app itself
      app_boot =
        boot
        |> BootScript.add_kernel_proc({Distillery.Releases.Runtime.Pidfile, :start, []})

      rel_dir = Release.version_path(release)
      bin_dir = Path.join(output_dir, "bin")

      with :ok <- BootScript.write(app_boot),
           :ok <- BootScript.write(app_boot, :start),
           :ok <- BootScript.write(clean_boot, :start_clean),
           :ok <- BootScript.write(clean_boot, :no_dot_erlang),
           :ok <- BootScript.write(config_boot, :config),
           # These two need to be copied to bin/ for ERTS
           :ok <-
             File.cp(
               Path.join(rel_dir, "start_clean.boot"),
               Path.join(bin_dir, "start_clean.boot")
             ),
           :ok <-
             File.cp(
               Path.join(rel_dir, "no_dot_erlang.boot"),
               Path.join(bin_dir, "no_dot_erlang.boot")
             ),
           :ok <- create_RELEASES(output_dir, Path.join(rel_dir, "#{name}.rel")) do
        :ok
      end
    end
  end

  # Generates RELEASES
  defp create_RELEASES(output_dir, relfile) do
    Shell.debug("Generating RELEASES")
    # NOTE: The RELEASES file must contain the correct paths to all libs,
    # including ERTS libs. When include_erts: false, the ERTS path, and thus
    # the paths to all ERTS libs, are not known until runtime. That means the
    # RELEASES file we generate here is invalid, which also means that performing
    # hot upgrades with include_erts: false will fail.
    #
    # This is annoying, but makes sense in the context of how release_handler works,
    # it must be able to handle upgrades where ERTS itself is also upgraded, and that
    # clearly can't happen if there is only one ERTS version (the host). It would be
    # possible to handle this if we could update the release_handler's state after it
    # unpacks a release in order to "fix" the invalid ERTS lib paths, but unfortunately
    # this is not exposed, and short of re-writing release_handler from scratch, there is
    # no work around for this
    old_cwd = File.cwd!()
    File.cd!(output_dir)

    :ok =
      :release_handler.create_RELEASES(
        File.cwd!(),
        Path.join([File.cwd!(), 'releases']),
        '#{relfile}',
        []
      )

    File.cd!(old_cwd)
    :ok
  end

  defp apply_overlays(%Release{} = release) do
    Shell.debug("Applying overlays")
    overlay_vars = release.profile.overlay_vars
    hooks_dir = "releases/<%= release_version %>/hooks"
    libexec_source = Path.join("#{:code.priv_dir(:distillery)}", "libexec")

    hook_overlays =
      [
        {:mkdir, hooks_dir},
        {:mkdir, "#{hooks_dir}/pre_configure.d"},
        {:mkdir, "#{hooks_dir}/post_configure.d"},
        {:mkdir, "#{hooks_dir}/pre_start.d"},
        {:mkdir, "#{hooks_dir}/post_start.d"},
        {:mkdir, "#{hooks_dir}/pre_stop.d"},
        {:mkdir, "#{hooks_dir}/post_stop.d"},
        {:mkdir, "#{hooks_dir}/pre_upgrade.d"},
        {:mkdir, "#{hooks_dir}/post_upgrade.d"},
        {:copy, release.profile.pre_configure_hooks, "#{hooks_dir}/pre_configure.d"},
        {:copy, release.profile.post_configure_hooks, "#{hooks_dir}/post_configure.d"},
        {:copy, release.profile.pre_start_hooks, "#{hooks_dir}/pre_start.d"},
        {:copy, release.profile.post_start_hooks, "#{hooks_dir}/post_start.d"},
        {:copy, release.profile.pre_stop_hooks, "#{hooks_dir}/pre_stop.d"},
        {:copy, release.profile.post_stop_hooks, "#{hooks_dir}/post_stop.d"},
        {:copy, release.profile.pre_upgrade_hooks, "#{hooks_dir}/pre_upgrade.d"},
        {:copy, release.profile.post_upgrade_hooks, "#{hooks_dir}/post_upgrade.d"},
        {:copy, libexec_source, "releases/<%= release_version %>/libexec"},
        {:mkdir, "releases/<%= release_version %>/commands"}
        | Enum.map(release.profile.commands, fn {name, path} ->
            ext =
              case Path.extname(path) do
                "" -> ".sh"
                other -> other
              end

            {:copy, path, "releases/<%= release_version %>/commands/#{name}#{ext}"}
          end)
      ]
      |> Enum.filter(fn
        {:copy, nil, _} -> false
        _ -> true
      end)

    output_dir = release.profile.output_dir
    overlays = hook_overlays ++ release.profile.overlays

    case Overlays.apply(output_dir, overlays, overlay_vars) do
      {:ok, paths} ->
        resolved_overlays =
          paths
          |> Enum.map(fn path -> {path, Path.join(output_dir, path)} end)

        release = %{release | resolved_overlays: resolved_overlays}

        {:ok, release}

      {:error, _} = err ->
        err
    end
  end

  defp generate_overlay_vars(%Release{profile: %Profile{erts_version: erts_vsn}} = release) do
    vars =
      [
        release: release,
        release_name: release.name,
        release_version: release.version,
        is_upgrade: release.is_upgrade,
        upgrade_from: release.upgrade_from,
        dev_mode: release.profile.dev_mode,
        include_erts: release.profile.include_erts,
        include_src: release.profile.include_src,
        include_system_libs: release.profile.include_erts,
        erl_opts: release.profile.erl_opts,
        run_erl_env: release.profile.run_erl_env,
        erts_vsn: erts_vsn,
        output_dir: release.profile.output_dir
      ] ++ release.profile.overlay_vars

    Shell.debug("Generated overlay vars:")

    inspected =
      vars
      |> Enum.map(fn
        {:release, _} -> nil
        {k, v} -> "#{k}=#{inspect(v)}"
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n    ")

    Shell.debugf("    #{inspected}\n")
    {:ok, %{release | :profile => %{release.profile | :overlay_vars => vars}}}
  end

  defp make_paths(%Release{} = release) do
    rel_dir = Release.version_path(release)
    bin_dir = Release.bin_path(release)
    lib_dir = Release.lib_path(release)

    with {_, :ok} <- {rel_dir, File.mkdir_p(rel_dir)},
         {_, :ok} <- {lib_dir, File.mkdir_p(lib_dir)},
         {_, :ok} <- {bin_dir, File.mkdir_p(bin_dir)} do
      :ok
    else
      {path, {:error, reason}} ->
        {:error, {:assembler, :file, {reason, path}}}
    end
  end

  # Strips debug info from the release, if so configured
  # We do not want to strip beams in dev_mode because it will strip Erlang/Elixir installation beams
  # due to being symlinked.
  # Additionally, we cannot strip debug info if this is going to be an upgrade, because the release handler
  # requires some of the chunks which are stripped, in both the upfrom and downfrom versions.
  defp strip_release(release) do
    path = release.profile.output_dir
    upgrade? = release.is_upgrade
    strip_debug_info? = release.profile.strip_debug_info
    dev_mode? = release.profile.dev_mode

    cond do
      not upgrade? and strip_debug_info? and not dev_mode? ->
        Shell.warn(
          "You have strip_debug_info set to true.\n" <>
            "    Please be aware that if you plan on performing hot upgrades later,\n" <>
            "    this setting will prevent you from doing so without a rolling restart.\n" <>
            "    You may ignore this warning if you have no plans to use hot upgrades."
        )

        Shell.debug("Stripping release (#{path})")

        case :beam_lib.strip_release(String.to_charlist(path)) do
          {:ok, _} ->
            :ok

          {:error, :beam_lib, reason} ->
            {:error, {:archiver, {:beam_lib, reason}}}
        end

      upgrade? and strip_debug_info? and not dev_mode? ->
        Shell.warn(
          "You have strip_debug_info set in your release configuration,\n" <>
            "    and you are performing an upgrade. This release will not be stripped,\n" <>
            "    however if you built your previous release with stripped debug information\n" <>
            "    this upgrade will fail, because the release handler will be unable to examine\n" <>
            "    the previous version's BEAM files. If you are using upgrades, it is recommended\n" <>
            "    that you do not set `strip_debug_info`"
        )

        :ok

      strip_debug_info? and dev_mode? ->
        Shell.warn(
          "You have strip_debug_info set while dev_mode is true,\n" <>
            "    this release will not be stripped, because it would result in\n" <>
            "    the symlinked BEAM files from Erlang/Elixir to be stripped as well"
        )

        :ok

      :else ->
        :ok
    end
  end
end
