defmodule Mix.Releases.Assembler do
  @moduledoc """
  This module is responsible for assembling a release based on a `Mix.Releases.Config`
  struct. It creates the release directory, copies applications, and generates release-specific
  files required by :systools and :release_handler.
  """
  alias Mix.Releases.{Config, Release, Environment, Profile, Utils, Logger}

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
    selected_environment = case config.selected_environment do
                             :default ->
                               case config.default_environment do
                                 :default -> Map.fetch(config.environments, :default)
                                 name -> Map.fetch(config.environments, name)
                               end
                             name -> Map.fetch(config.environments, name)
                           end
    selected_release = case config.selected_release do
                         :default ->
                           case config.default_release do
                             :default -> List.first(Map.values(config.releases))
                             name -> Map.fetch(config.releases, name)
                           end
                         name -> Map.fetch(config.releases, name)
                       end
    selected_environment = case selected_environment do
                             :error       -> {:error, :no_environments}
                             {:ok, _} = e -> e
                           end
    selected_release = case selected_release do
                         :error       -> {:error, :no_releases}
                         {:ok, _} = r -> r
                       end
    with {:ok, environment} <- selected_environment,
         {:ok, release}     <- selected_release,
         {:ok, release}     <- apply_environment(release, environment),
         {:ok, output_dir}  <- create_output_dir(release),
         {:ok, apps}        <- copy_applications(release, output_dir),
         :ok                <- create_release_info(release, output_dir, apps),
         {:ok, release}     <- strip_release(release, output_dir),
      do: {:ok, release}
  end

  defp apply_environment(%Release{profile: rel_profile} = r, %Environment{profile: env_profile} = e) do
    Logger.info "Building release #{r.name}:#{r.version} using environment #{e.name}"
    profile = Enum.reduce(env_profile, rel_profile, fn {k, v}, acc ->
      case v do
        nil -> acc
        _   -> Map.put(acc, k, v)
      end
    end)
    %{r | :profile => profile}
  end

  defp create_output_dir(%Release{name: name}) do
    output_dir = Path.relative_to_cwd(Path.join("rel", "#{name}"))
    File.mkdir_p!(output_dir)
    {:ok, output_dir}
  end

  defp copy_applications(%Release{} = release, output_dir) do
    try do
      File.mkdir_p!(Path.join(output_dir, "lib"))
      apps = release
        |> get_apps
        |> Enum.map(&get_app_metadata(&1, release.applications))
      for app <- apps do
        copy_app(output_dir, app, release)
      end
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

  defp get_apps(%Release{name: name, applications: apps}) do
    Application.load(name)
    children = get_apps(Application.spec(name), [name])
    Enum.reduce(apps, children, fn
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
        release_file = Path.join(rel_dir, "#{relname}.rel")
        start_clean_file = Path.join(rel_dir, "start_clean.rel")
        start_clean_release = %{release | :applications => [:kernel, :stdlib]}
        write_relfile(release_file, release, apps)
        start_clean_apps = Enum.map(start_clean_release.applications, &get_app_metadata(&1, release.applications))
        write_relfile(start_clean_file, start_clean_release, start_clean_apps)
        write_binfile(release, output_dir, rel_dir)
        :ok
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
    write_terms(path, relfile)
  end

  defp write_terms(path, terms) do
    :file.write_file('#{path}', :io_lib.fwrite('~p.\n', [terms]), [encoding: :utf8])
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

  defp generate_nodetool!(bin_dir) do
    node_tool_file = Utils.template(:nodetool)
    install_upgrade_file = Utils.template(:install_upgrade)
    File.write!(Path.join(bin_dir, "nodetool"), node_tool_file)
    File.write!(Path.join(bin_dir, "install_upgrade.escript"), install_upgrade_file)
    :ok
  end

  defp generate_start_erl_data!(release, rel_dir) do
    contents = "#{Utils.erts_version} #{release.version}"
    File.write!(Path.join([rel_dir, "..", "start_erl.data"]), contents)
    :ok
  end

  defp generate_vm_args!(%Release{profile: %Profile{vm_args: nil}} = release, rel_dir) do
    contents = Utils.template("vm.args", [rel_name: "#{release.name}"])
    File.write!(Path.join(rel_dir, "vm.args"), contents)
    :ok
  end
  defp generate_vm_args!(%Release{profile: %Profile{vm_args: path}}, rel_dir) do
    File.cp!(path, Path.join(rel_dir, "vm.args"))
    :ok
  end

  defp generate_sys_config!(_release, rel_dir) do
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
    write_terms(Path.join(rel_dir, "sys.config"), config)
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
    get_apps(release)
    |> Enum.map(&get_app_metadata(&1, release.applications))
    |> Enum.map(fn %{name: name, version: version} ->
      lib_dir = Path.join([output_dir, "lib", "#{name}-#{version}", "ebin"])
      String.to_charlist(lib_dir)
    end)
  end

  defp create_RELEASES(output_dir, relfile) do
    old_cwd = File.cwd!
    File.cd!(output_dir)
    :ok = :release_handler.create_RELEASES('./', 'releases', '#{relfile}', [])
    File.cd!(old_cwd)
    :ok
  end

  defp create_start_clean(rel_dir, output_dir, options) do
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
    case :beam_lib.strip_release(output_dir) do
      :ok ->
        {:ok, release}
      {:error, _, reason} ->
        {:error, "failed to strip release: #{inspect reason}"}
    end
  end
  defp strip_release(%Release{} = release, _), do: {:ok, release}
end
