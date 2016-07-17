defmodule Mix.Releases.Assembler do
  @moduledoc """
  This module is responsible for assembling a release based on a `Mix.Releases.Config`
  struct. It creates the release directory, copies applications, and generates release-specific
  files required by :systools and :release_handler.
  """
  alias Mix.Releases.{Config, Release, Environment, Profile, Utils, Logger, Appup}

  require Record
  Record.defrecordp :file_info, Record.extract(:file_info, from_lib: "kernel/include/file.hrl")

  @doc """
  This function takes a Config struct and assembles the release.

  **Note: This operation has side-effects!** It creates files, directories,
  copies files from other filesystem locations. If failures occur, no cleanup
  of files/directories is performed. However, all files/directories created by
  this function are scoped to the current project's `rel` directory, and cannot
  impact the filesystem outside of this directory.
  """
  @spec assemble(Config.t) :: {:ok, Config.t} | {:error, term}
  def assemble(%Config{} = config) do
    with {:ok, environment} <- select_environment(config),
         {:ok, release}     <- select_release(config),
         {:ok, release}     <- apply_environment(release, environment),
         {:ok, release}     <- apply_configuration(release, config),
         {:ok, output_dir}  <- create_output_dir(release),
         {:ok, apps}        <- copy_applications(release, output_dir),
         :ok                <- create_release_info(release, output_dir, apps),
         {:ok, release}     <- strip_release(release, output_dir),
      do: {:ok, release}
  end

  defp select_environment(%Config{selected_environment: :default, default_environment: :default} = c),
    do: select_environment(Map.fetch(c.environments, :default))
  defp select_environment(%Config{selected_environment: :default, default_environment: name} = c),
    do: select_environment(Map.fetch(c.environments, name))
  defp select_environment(%Config{selected_environment: name} = c),
    do: select_environment(Map.fetch(c.environments, name))
  defp select_environment({:ok, _} = e), do: e
  defp select_environment(_),            do: {:error, :no_environments}

  defp select_release(%Config{selected_release: :default, default_release: :default} = c),
    do: {:ok, List.first(Map.values(c.releases))}
  defp select_release(%Config{selected_release: :default, default_release: name} = c),
    do: select_release(Map.fetch(c.releases, name))
  defp select_release(%Config{selected_release: name} = c),
    do: select_release(Map.fetch(c.releases, name))
  defp select_release({:ok, _} = r), do: r
  defp select_release(_),            do: {:error, :no_releases}

  defp apply_environment(%Release{profile: rel_profile} = r, %Environment{profile: env_profile} = e) do
    Logger.info "Building release #{r.name}:#{r.version} using environment #{e.name}"
    env_profile = Map.from_struct(env_profile)
    profile = Enum.reduce(env_profile, rel_profile, fn {k, v}, acc ->
      case v do
        nil -> acc
        _   -> Map.put(acc, k, v)
      end
    end)
    {:ok, %{r | :profile => profile}}
  end

  defp apply_configuration(%Release{version: current_version} = release, %Config{} = config) do
    case config.is_upgrade do
      true ->
        case config.upgrade_from do
          :latest ->
            upfrom = case Utils.get_release_versions(release.output_dir) do
              [] -> :no_upfrom
              [^current_version, v|_] -> v
              [v|_] -> v
            end
            case upfrom do
              :no_upfrom ->
                Logger.warn "An upgrade was requested, but there are no " <>
                  "releases to upgrade from, no upgrade will be performed."
                {:ok, %{release | :is_upgrade => false, :upgrade_from => nil}}
              v ->
                {:ok, %{release | :is_upgrade => true, :upgrade_from => v}}
            end
          ^current_version ->
            Logger.error "Upgrade from #{current_version} to #{current_version} failed:\n  " <>
              "Upfrom version and current version are the same"
            {:error, :bad_upgrade_spec}
          version when is_binary(version) ->
            Logger.debug "Upgrading #{release.name} from #{version} to #{current_version}"
            upfrom_path = Path.join([release.output_dir, "releases", version])
            case File.exists?(upfrom_path) do
              false ->
                Logger.error "Upgrade from #{version} to #{current_version} failed:\n  " <>
                  "#{version} does not exist at #{upfrom_path}"
                {:error, :bad_upgrade_spec}
              true ->
                {:ok, %{release | :is_upgrade => true, :upgrade_from => version}}
            end
        end
      false ->
        {:ok, release}
    end
  end

  defp create_output_dir(%Release{output_dir: output_dir}) do
    File.mkdir_p!(output_dir)
    {:ok, output_dir}
  end

  defp copy_applications(%Release{} = release, output_dir) do
    Logger.debug "Copying applications to #{output_dir}"
    try do
      File.mkdir_p!(Path.join(output_dir, "lib"))
      apps = release
        |> get_apps
        |> Enum.map(&get_app_metadata(&1, release.applications))
      for app <- apps do
        copy_app(output_dir, app, release)
      end
      # Copy consolidated .beams
      build_path = Mix.Project.build_path(Mix.Project.config)
      File.cp_r!(
        Path.join(build_path, "consolidated"),
        Path.join([output_dir, "lib", "#{release.name}-#{release.version}", "consolidated"]))
      {:ok, apps}
    rescue
      err ->
        {:error, {:copy_applications, err.__struct__.message(err)}}
    end
  end

  defp copy_app(output_dir, app, %Release{profile: %Profile{dev_mode: dev_mode?, include_src: include_src?, include_erts: include_erts?}}) do
    app_name    = app.name
    app_version = app.version
    app_dir     = app.path
    lib_dir     = Path.join(output_dir, "lib")
    target_dir  = Path.join(lib_dir, "#{app_name}-#{app_version}")
    remove_symlink_or_dir!(target_dir)
    case include_erts? do
      true ->
        copy_app(app_dir, target_dir, dev_mode?, include_src?)
      _ ->
        case is_erts_lib?(app_dir) do
          true ->
            :ok
          false ->
            copy_app(app_dir, target_dir, dev_mode?, include_src?)
        end
    end
  end
  defp copy_app(app_dir, target_dir, true, _include_src?) do
    case File.ln_s(app_dir, target_dir) do
      :ok -> :ok
      {:error, reason} ->
        raise "unable to link app directory:\n  " <>
          "#{app_dir} -> #{target_dir}\n  " <>
          "Reason: #{reason}"
    end
  end
  defp copy_app(app_dir, target_dir, false, include_src?) do
    case include_src? do
      true ->
        case File.cp_r(app_dir, target_dir) do
          {:ok, _} -> :ok
          {:error, reason, file} ->
            raise "unable to copy app directory:\n  " <>
              "#{app_dir} -> #{target_dir}\n  " <>
              "File: #{file}\n  " <>
              "Reason: #{reason}"
        end
      false ->
        case File.mkdir_p(target_dir) do
          {:error, reason} ->
            raise "unable to create app directory:\n  " <>
              "#{target_dir}\n  " <>
              "Reason: #{reason}"
          :ok ->
            Path.wildcard(Path.join(app_dir, "*"))
            |> Enum.filter(fn p -> Path.basename(p) in ["ebin", "include", "priv", "lib"] end)
            |> Enum.each(fn p ->
              t = Path.join(target_dir, Path.basename(p))
              case File.cp_r(p, t) do
                {:ok, _} -> :ok
                {:error, reason, file} ->
                  raise "unable to copy app directory:\n  " <>
                    "#{p} -> #{t}\n  " <>
                    "File: #{file}\n  " <>
                    "Reason: #{reason}"
              end
            end)
        end
    end
  end

  defp is_erts_lib?(app_dir) do
    String.starts_with?(app_dir, "#{:code.lib_dir()}")
  end

  defp get_apps(release), do: get_apps(release, true)
  defp get_apps(%Release{name: name, applications: apps}, show_debug?) do
    Application.load(name)
    children = get_apps(Application.spec(name), [name])
    apps = Enum.reduce(apps, children, fn
      {a, _}, acc ->
        case (a in acc) do
          true  -> acc
          false -> get_apps(Application.spec(a), [a|acc])
        end
      a, acc when is_atom(a) ->
        case (a in acc) do
          true  -> acc
          false -> get_apps(Application.spec(a), [a|acc])
        end
    end)
    if show_debug? && Application.get_env(:mix, :release_logger_verbosity) == :verbose do
      Logger.debug "Discovered applications:"
      Enum.each(apps, fn a ->
        Application.load(a)
        app           = Application.spec(a)
        ver           = Keyword.fetch!(app, :vsn)
        applications  = Keyword.get(app, :applications, [])
        included_apps = Keyword.get(app, :included_applications, [])
        where = case :code.lib_dir(a) do
                  {:error, _} ->
                    case Utils.get_mix_dep(a, :dest) do
                      nil  -> :unknown
                      path -> Path.relative_to_cwd(path)
                    end
                  p -> Path.relative_to_cwd(List.to_string(p))
                end
        IO.puts "  #{a}-#{ver}\n" <>
          "    #{IO.ANSI.cyan}from: #{where}"
        case applications do
          [] ->
            IO.puts "    applications: none"
          _  ->
            IO.puts "    applications:\n" <>
              "      #{Enum.map(applications, &Atom.to_string/1) |> Enum.join("\n      ")}"
        end
        case included_apps do
          [] ->
            IO.puts "    includes: none#{IO.ANSI.reset}\n"
          _ ->
            IO.puts "    includes:\n" <>
              "      #{Enum.map(included_apps, &Atom.to_string/1) |> Enum.join("\n     ")}#{IO.ANSI.reset}"
        end
      end)
    end
    apps
  end
  defp get_apps(nil, acc) do
    Enum.uniq(acc)
  end
  defp get_apps(spec, acc) do
    spec
    |> Keyword.get(:applications, [])
    |> Enum.reduce(acc, fn a, acc ->
      case (a in acc) do
        true -> acc
        false ->
          Application.load(a)
          as = get_apps(Application.spec(a), [a|acc])
          Enum.concat(acc, as)
      end
    end)
    |> Enum.uniq
  end

  defp remove_symlink_or_dir!(path) do
    case File.exists?(path) do
      true ->
        File.rm_rf!(path)
        :ok
      false ->
        :ok
    end
  end

  defp get_app_metadata(app, configured_apps) do
    app = case app do
      {a, _} -> a
      a -> a
    end
    config = Enum.find(configured_apps, fn {^app, _} -> true; _ -> false end)
    Application.load(app)
    spec = Application.spec(app)
    type = case config do
             {_, type} when type in [:permanent, :transient, :temporary, :load, :none] ->
               type
             _ ->
               nil
           end
    %{name: app,
      version: Keyword.get(spec, :vsn),
      path: Application.app_dir(app),
      type: type,
      included: Keyword.get(spec, :included_applications)}
  end

  defp create_release_info(%Release{:name => relname} = release, output_dir, apps) do
    rel_dir = Path.join([output_dir, "releases", "#{release.version}"])
    case File.mkdir_p(rel_dir) do
      {:error, reason} ->
        {:error, "failed to create release directory: #{rel_dir}\n  Reason: #{reason}"}
      :ok ->
        release_file     = Path.join(rel_dir, "#{relname}.rel")
        start_clean_file = Path.join(rel_dir, "start_clean.rel")
        start_clean_rel  = %{release | :applications => [:kernel, :stdlib]}
        start_clean_apps = Enum.map(start_clean_rel.applications, &get_app_metadata(&1, release.applications))
        with :ok <- write_relfile(release_file, release, apps),
             :ok <- write_relfile(start_clean_file, start_clean_rel, start_clean_apps),
             :ok <- write_binfile(release, output_dir, rel_dir),
             :ok <- generate_relup(release, output_dir, rel_dir), do: :ok
    end
  end

  defp write_relfile(path, %Release{} = release, apps) do
    relfile = {:release,
                 {'#{release.name}', '#{release.version}'},
                 {:erts, '#{Utils.erts_version}'},
                Enum.map(apps, fn %{:name => name, :version => vsn, :type => type} ->
                  case type do
                    nil ->
                      {name, '#{vsn}'}
                    t ->
                      {name, '#{vsn}', t}
                  end
                end)}
    Utils.write_term(path, relfile)
  end

  defp write_binfile(release, output_dir, rel_dir) do
    name = "#{release.name}"
    version = release.version
    bin_dir = Path.join(output_dir, "bin")
    File.mkdir_p!(bin_dir)
    bootloader_path = Path.join(bin_dir, name)
    boot_path = Path.join(rel_dir, "#{name}.sh")

    generate_nodetool!(bin_dir)

    template_params = [rel_name: name, rel_vsn: version,
                       erts_vsn: Utils.erts_version(), erl_opts: release.profile.erl_opts]
    bootloader_contents = Utils.template(:boot_loader, template_params)
    boot_contents = Utils.template(:boot, template_params)
    File.write!(bootloader_path, bootloader_contents)
    File.write!(boot_path, boot_contents)
    File.chmod!(bootloader_path, 0o777)
    File.chmod!(boot_path, 0o777)

    generate_start_erl_data!(release, rel_dir)
    generate_vm_args!(release, rel_dir)
    generate_sys_config!(release, rel_dir)
    include_erts!(release, output_dir, rel_dir)
  end

  defp generate_relup(%Release{is_upgrade: false}, _output_dir, _rel_dir), do: :ok
  defp generate_relup(%Release{name: name, upgrade_from: upfrom} = release, output_dir, rel_dir) do
    Logger.debug "Generating relup for #{name}"
    v1_rel = Path.join([output_dir, "releases", upfrom, "#{name}.rel"])
    v2_rel = Path.join(rel_dir, "#{name}.rel")
    case {File.exists?(v1_rel), File.exists?(v2_rel)} do
      {false, true} ->
        {:error, "Missing .rel for #{name}:#{upfrom} at #{v1_rel}"}
      {true, false} ->
        {:error, "Missing .rel for #{name}:#{release.version} at #{v2_rel}"}
      {false, false} ->
        {:error, "Missing .rels\n  " <>
          "#{name}:#{upfrom} @ #{v1_rel}\n  " <>
          "#{name}:#{release.version} @ #{v2_rel}"}
      {true, true} ->
        v1_apps = extract_relfile_apps(v1_rel)
        v2_apps = extract_relfile_apps(v2_rel)
        changed = get_changed_apps(v1_apps, v2_apps)
        added   = get_added_apps(v2_apps, changed)
        case generate_appups(changed, output_dir) do
          {:error, _} = err ->
            err
          :ok ->
            # Remove _build dir from code path
            #build_path = Mix.Project.build_path(Mix.Project.config)
            #for path <- :code.get_path, String.starts_with?("#{path}", build_path) do
              #Code.delete_path(List.to_string(path))
            #end
            current_rel = Path.join([output_dir, "releases", release.version, "#{name}"])
            upfrom_rel  = Path.join([output_dir, "releases", release.upgrade_from, "#{name}"])
            result = :systools.make_relup(
              String.to_charlist(current_rel),
              [String.to_charlist(upfrom_rel)],
              [String.to_charlist(upfrom_rel)],
              [{:outdir, String.to_charlist(rel_dir)},
               {:path, get_relup_code_paths(added, changed, output_dir)},
               :silent,
               :no_warn_sasl]
            )
            case result do
              {:ok, relup, _mod, []} ->
                Logger.info "Relup successfully created"
                Utils.write_term(Path.join(rel_dir, "relup"), relup)
              {:ok, relup, mod, warnings} ->
                Logger.warn format_systools_warning(mod, warnings)
                Logger.info "Relup successfully created"
                Utils.write_term(Path.join(rel_dir, "relup"), relup)
              {:error, mod, errors} ->
                error = format_systools_error(mod, errors)
                {:error, error}
            end
        end
    end
  end

  defp format_systools_warning(mod, warnings) do
    warning = mod.format_warning(warnings)
    |> IO.iodata_to_binary
    |> String.split("\n")
    |> Enum.map(fn e -> "    " <> e end)
    |> Enum.join("\n")
    |> String.trim_trailing
    "\n#{warning}"
  end

  defp format_systools_error(mod, errors) do
    error = mod.format_error(errors)
    |> IO.iodata_to_binary
    |> String.split("\n")
    |> Enum.map(fn e -> "    " <> e end)
    |> Enum.join("\n")
    |> String.trim_trailing
    "\n#{error}"
  end

  defp extract_relfile_apps(path) do
    case Utils.read_terms(path) do
      {:error, err} -> raise err
      {:ok, [{:release, _rel, _erts, apps}]} -> apps
    end
  end

  defp get_changed_apps(a, b) do
    as = Enum.map(a, fn app -> elem(app, 0) end) |> MapSet.new
    bs = Enum.map(b, fn app -> elem(app, 0) end) |> MapSet.new
    shared = MapSet.to_list(MapSet.intersection(as, bs))
    a_versions = Enum.map(shared, fn n -> {n, elem(List.keyfind(a, n, 0), 1)} end) |> MapSet.new
    b_versions = Enum.map(shared, fn n -> {n, elem(List.keyfind(b, n, 0), 1)} end) |> MapSet.new
    MapSet.difference(b_versions, a_versions)
    |> MapSet.to_list
    |> Enum.map(fn {n, v2} ->
      v1 = List.keyfind(a, n, 0) |> elem(1)
      {n, "#{v1}", "#{v2}"}
    end)
  end

  defp get_added_apps(v2_apps, changed) do
    changed_apps = Enum.map(changed, &elem(&1, 0))
    Enum.reject(v2_apps, fn a ->
      elem(a, 0) in changed_apps
    end)
  end

  defp generate_appups([], _output_dir), do: :ok
  defp generate_appups([{app, v1, v2}|apps], output_dir) do
    v1_path       = Path.join([output_dir, "lib", "#{app}-#{v1}"])
    v2_path       = Path.join([output_dir, "lib", "#{app}-#{v2}"])
    appup_path    = Path.join([v2_path, "ebin", "#{app}.appup"])
    appup_exists? = File.exists?(appup_path)
    cond do
      appup_exists? ->
        Logger.debug "#{app} requires an appup, and one was provided, skipping generation.."
        generate_appups(apps, output_dir)
      :else ->
        Logger.debug "#{app} requires an appup, but it wasn't provided, one will be generated for you.."
        case Appup.make(app, v1, v2, v1_path, v2_path) do
          {:error, reason} ->
            {:error, "Failed to generate appup for #{app}:\n    " <>
              inspect(reason)}
          {:ok, appup} ->
            :ok = Utils.write_term(appup_path, appup)
            Logger.info "Generated .appup for #{app} #{v1} -> #{v2}"
            generate_appups(apps, output_dir)
        end
    end
  end

  defp get_relup_code_paths(added, changed, output_dir) do
    added_paths   = get_added_relup_code_paths(added, output_dir, [])
    changed_paths = get_changed_relup_code_paths(changed, output_dir, [], [])
    added_paths ++ changed_paths
  end
  defp get_changed_relup_code_paths([], _output_dir, v1_paths, v2_paths) do
    v2_paths ++ v1_paths
  end
  defp get_changed_relup_code_paths([{app, v1, v2}|apps], output_dir, v1_paths, v2_paths) do
    v1_path = Path.join([output_dir, "lib", "#{app}-#{v1}", "ebin"]) |> String.to_charlist
    v2_path = Path.join([output_dir, "lib", "#{app}-#{v2}", "ebin"]) |> String.to_charlist
    v2_path_consolidated = Path.join([output_dir, "lib", "#{app}-#{v2}", "consolidated"]) |> String.to_charlist
    get_changed_relup_code_paths(
      apps,
      output_dir,
      [v1_path|v1_paths],
      [v2_path_consolidated, v2_path|v2_paths])
  end
  defp get_added_relup_code_paths([], _output_dir, paths), do: paths
  defp get_added_relup_code_paths([{app, v2}|apps], output_dir, paths) do
    v2_path = Path.join([output_dir, "lib", "#{app}-#{v2}", "ebin"]) |> String.to_charlist
    v2_path_consolidated = Path.join([output_dir, "lib", "#{app}-#{v2}", "consolidated"]) |> String.to_charlist
    get_added_relup_code_paths(apps, output_dir, [v2_path_consolidated, v2_path|paths])
  end

  defp generate_nodetool!(bin_dir) do
    Logger.debug "Generating nodetool"
    node_tool_file = Utils.template(:nodetool)
    install_upgrade_file = Utils.template(:install_upgrade)
    File.write!(Path.join(bin_dir, "nodetool"), node_tool_file)
    File.write!(Path.join(bin_dir, "install_upgrade.escript"), install_upgrade_file)
    :ok
  end

  defp generate_start_erl_data!(release, rel_dir) do
    Logger.debug "Generating start_erl.data"
    contents = "#{Utils.erts_version} #{release.version}"
    File.write!(Path.join([rel_dir, "..", "start_erl.data"]), contents)
    :ok
  end

  defp generate_vm_args!(%Release{profile: %Profile{vm_args: nil}} = release, rel_dir) do
    Logger.debug "Generating vm.args"
    contents = Utils.template("vm.args", [rel_name: "#{release.name}"])
    File.write!(Path.join(rel_dir, "vm.args"), contents)
    :ok
  end
  defp generate_vm_args!(%Release{profile: %Profile{vm_args: path}}, rel_dir) do
    Logger.debug "Copying user-provided vm.args"
    File.cp!(path, Path.join(rel_dir, "vm.args"))
    :ok
  end

  defp generate_sys_config!(_release, rel_dir) do
    Logger.debug "Generating sys.config"
    config_path = Keyword.get(Mix.Project.config, :config_path)
    config = Mix.Config.read!(config_path)
    case Keyword.get(config, :sasl) do
      nil -> Keyword.put(config, :sasl, [errlog_type: :error])
      sasl ->
        case Keyword.get(sasl, :errlog_type) do
          nil -> put_in(config, [:sasl, :errlog_type], :error)
          _   -> config
        end
    end
    Utils.write_term(Path.join(rel_dir, "sys.config"), config)
    :ok
  end

  defp include_erts!(%Release{profile: %Profile{include_erts: false}}, _output_dir, _rel_dir), do: :ok
  defp include_erts!(%Release{profile: %Profile{include_erts: include_erts}} = release, output_dir, rel_dir) do
    prefix = case include_erts do
               true -> "#{:code.root_dir}"
               p when is_binary(p) -> Path.absname(p)
             end
    erts_vsn = Utils.erts_version()
    erts_dir = Path.join(prefix, "erts-#{erts_vsn}")
    Logger.info "Including ERTS #{erts_vsn} from #{Path.relative_to_cwd(erts_dir)}"
    erts_output_dir = Path.join(output_dir, "erts-#{erts_vsn}")
    # Remove old one
    if File.exists?(erts_output_dir) do
      File.rm_rf!(erts_output_dir)
    end
    File.mkdir_p!(erts_output_dir)
    File.cp_r!(erts_dir, erts_output_dir)
    erl_path = Path.join([erts_output_dir, "bin", "erl"])
    File.rm_rf(erl_path)
    File.write!(erl_path, Utils.template(:erl_script, [erts_vsn: erts_vsn]))
    File.chmod!(erl_path, 0o755)
    nodetool_path = Path.join([output_dir, "bin", "nodetool"])
    nodetool_dest = Path.join([erts_output_dir, "bin", "nodetool"])
    install_upgrade_path = Path.join([output_dir, "bin", "install_upgrade.escript"])
    install_upgrade_dest = Path.join([erts_output_dir, "bin", "install_upgrade.escript"])
    File.cp!(nodetool_path, nodetool_dest)
    File.cp!(install_upgrade_path, install_upgrade_dest)
    File.chmod!(nodetool_dest, 0o755)
    File.chmod!(install_upgrade_dest, 0o755)

    make_boot_script!(release, output_dir, rel_dir)
  end

  defp make_boot_script!(release, output_dir, rel_dir) do
    Logger.debug "Generating boot script"
    options = [{:path, ['#{rel_dir}' | get_code_paths(release, output_dir)]},
               {:outdir, '#{rel_dir}'},
               {:variables, [{'ERTS_LIB_DIR', :code.lib_dir()}]},
               :no_warn_sasl,
               :no_module_tests,
               :silent]
    rel_name = '#{release.name}'
    release_file = Path.join(rel_dir, "#{release.name}.rel")
    case :systools.make_script(rel_name, options) do
      :ok ->
        create_RELEASES(output_dir, Path.join(["releases", "#{release.version}", "#{release.name}.rel"]))
        create_start_clean(rel_dir, output_dir, options)
        :ok
      {:ok, _, []} ->
        create_RELEASES(output_dir, Path.join(["releases", "#{release.version}", "#{release.name}.rel"]))
        create_start_clean(rel_dir, output_dir, options)
        :ok
      :error ->
        raise "make boot script, :error"
        {:error, {:unknown, release_file}}
      {:ok, mod, warnings} ->
        raise "make boot script warn, #{mod}: #{inspect warnings}"
        {:error, {mod, warnings}}
      {:error, mod, errors} ->
        raise "make boot script error, #{mod}: #{inspect errors}"
        {:error, {mod, errors}}
    end
  end

  defp get_code_paths(release, output_dir) do
    get_apps(release, false)
    |> Enum.map(&get_app_metadata(&1, release.applications))
    |> Enum.map(fn %{name: name, version: version} ->
      lib_dir = Path.join([output_dir, "lib", "#{name}-#{version}", "ebin"])
      String.to_charlist(lib_dir)
    end)
  end

  defp create_RELEASES(output_dir, relfile) do
    Logger.debug "Generating RELEASES"
    old_cwd = File.cwd!
    File.cd!(output_dir)
    :ok = :release_handler.create_RELEASES('./', 'releases', '#{relfile}', [])
    File.cd!(old_cwd)
    :ok
  end

  defp create_start_clean(rel_dir, output_dir, options) do
    Logger.debug "Generating start_clean.boot"
    case :systools.make_script('start_clean', options) do
      :ok ->
        File.cp!(Path.join(rel_dir, "start_clean.boot"),
                 Path.join([output_dir, "bin", "start_clean.boot"]))
        File.rm!(Path.join(rel_dir, "start_clean.rel"))
        File.rm!(Path.join(rel_dir, "start_clean.script"))
        :ok
      :error ->
        {:error, {:unknown, :create_start_clean}}
      {:ok, _, []} ->
        File.cp!(Path.join(rel_dir, "start_clean.boot"),
                 Path.join([output_dir, "bin", "start_clean.boot"]))
        File.rm!(Path.join(rel_dir, "start_clean.rel"))
        File.rm!(Path.join(rel_dir, "start_clean.script"))
        :ok
      {:ok, mod, warnings} ->
        {:error, {mod, warnings}}
      {:error, mod, errors} ->
        {:error, {mod, errors}}
    end
  end

  defp strip_release(%Release{profile: %Profile{strip_debug_info: true, dev_mode: true}} = release, output_dir) do
    Logger.debug "Stripping release"
    case :beam_lib.strip_release(output_dir) do
      :ok ->
        {:ok, release}
      {:error, _, reason} ->
        {:error, "failed to strip release: #{inspect reason}"}
    end
  end
  defp strip_release(%Release{} = release, _), do: {:ok, release}
end
