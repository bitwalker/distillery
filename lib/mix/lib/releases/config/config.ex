defmodule Mix.Releases.Config do
  @moduledoc """
  Responsible for parsing the release configuration file.
  """

  alias Mix.Releases.{Release, Environment}
  alias Mix.Releases.Config.LoadError

  defstruct environments: %{},
            releases: %{},
            default_release: :default,
            default_environment: :default,
            selected_release: :default,
            selected_environment: :default,
            is_upgrade: false,
            upgrade_from: :latest # the version to upgrade from (if applicable)

  @type t :: %__MODULE__{
    environments: Map.t,
    releases: Map.t,
    default_release: atom(),
    default_environment: atom(),
    selected_release: atom(),
    selected_environment: atom(),
    is_upgrade: boolean(),
    upgrade_from: :latest | String.t
  }

  defmacro __using__(opts) do
    quote do
      import Mix.Releases.Config
      # Initialize config state
      {:ok, agent} = Mix.Config.Agent.start_link
      Mix.Config.Agent.merge agent, [
        environments: [],
        releases: [],
        default_release: Keyword.get(unquote(opts), :default_release, :default),
        default_environment: Keyword.get(unquote(opts), :default_environment, :default)
      ]
      var!(config_agent, Mix.Releases.Config) = agent
      var!(current_env, Mix.Releases.Config) = nil
      var!(current_rel, Mix.Releases.Config) = nil
    end
  end

  @doc false
  @spec get() :: __MODULE__.t | {:error, {:config, :not_found | String.t}}
  @spec get(Keyword.t) :: __MODULE__.t | {:error, {:config, :not_found | String.t}}
  def get(opts \\ []) do
    config_path = Path.join([File.cwd!, "rel", "config.exs"])
    case File.exists?(config_path) do
      true ->
        base_config = try do
          read!(config_path)
        rescue
          e in [Config.LoadError] ->
            file = Path.relative_to_cwd(e.file)
          message = Exception.message(e)
          message = String.replace(message, "nofile", file)
          {:error, {:config, message}}
        end
        case base_config do
          {:error, _} = err -> err
          _ ->
            {:ok, %{base_config |
              :environments => Enum.into(Enum.map(base_config.environments, fn {name, e} ->
                    {name, %{e | :profile => %{e.profile |
                                               :dev_mode => get_opt(opts, :dev_mode, e.profile.dev_mode),
                                               :executable => get_opt(opts, :executable, e.profile.executable),
                                               :erl_opts => get_opt(opts, :erl_opts, e.profile.erl_opts),
                                               :run_erl_env => get_opt(opts, :run_erl_env, e.profile.run_erl_env),
                                               :exec_opts => Enum.into(get_opt(opts, :exec_opts, e.profile.exec_opts), %{})}}}
                  end), %{}),
              :is_upgrade => Keyword.fetch!(opts, :is_upgrade),
              :upgrade_from => Keyword.fetch!(opts, :upgrade_from),
              :selected_environment => Keyword.fetch!(opts, :selected_environment),
              :selected_release => Keyword.fetch!(opts, :selected_release)}}
        end
      false ->
        {:error, {:config, :not_found}}
    end
  end
  defp get_opt(opts, key, default) do
    val = Keyword.get(opts, key)
    cond do
      is_nil(val) -> default
      :else -> val
    end
  end

  @doc """
  Creates a new environment for building releases. Within an
  environment, you can set config options which apply to all
  releases built in that environment.

  ## Usage

      environment :dev do
        set dev_mode: true
        set include_erts: false
      end

  """
  defmacro environment(name, do: block) do
    quote do
      unless is_atom(unquote(name)) do
        raise "environment name must be an atom! got #{inspect unquote(name)}"
      end
      env = Environment.new(unquote(name))
      Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
        [environments: [{unquote(name), env}]]
      var!(current_env, Mix.Releases.Config) = unquote(name)
      unquote(block)
      var!(current_env, Mix.Releases.Config) = nil
    end
  end

  @default_release_version "0.1.0"
  @doc """
  Creates a new release definition with the given name.
  Within a release definition, you can set config options specific
  to that release

  ## Usage

      release :myapp do
        set version: "0.1.0",
        set applications: [:other_app]
        set code_paths: ["/some/code/path"]
      end

  """
  defmacro release(name, do: block) do
    quote do
      unless is_atom(unquote(name)) do
        raise "release name must be an atom! got #{inspect unquote(name)}"
      end
      rel = Release.new(unquote(name), unquote(@default_release_version), [unquote(name)])
      Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
        [releases: [{unquote(name), rel}]]
      var!(current_rel, Mix.Releases.Config) = unquote(name)
      unquote(block)
      var!(current_rel, Mix.Releases.Config) = nil
    end
  end

  @doc """
  Adds a plugin to the environment or release definition it is part of.
  Plugins will be called in the order they are defined. In the example
  below `MyApp.ReleasePlugin` will be called, then `MyApp.MigratePlugin`

  ## Usage

      release :myapp do
        plugin MyApp.ReleasePlugin
        plugin MyApp.MigratePlugin
      end

  """
  defmacro plugin(name, opts \\ []) do
    name = case name do
             n when is_atom(n) -> n
             {:__aliases__, _, module_parts} -> Module.concat(module_parts)
           end
    quote do
      current_env = var!(current_env, Mix.Releases.Config)
      current_rel = var!(current_rel, Mix.Releases.Config)
      if current_env == nil && current_rel == nil do
        raise "cannot use plugin/1 outside of an environment or a release!"
      end
      case :code.which(unquote(name)) do
        :non_existing ->
          raise "cannot load plugin #{unquote(name)}, no such module could be found"
        _ ->
          :ok
      end
      config = Mix.Config.Agent.get(var!(config_agent, Mix.Releases.Config))
      cond do
        current_env != nil ->
          env = get_in(config, [:environments, current_env])
          profile = env.profile
          plugins = profile.plugins ++ [{unquote(name), unquote(opts)}]
          env = %{env | :profile => %{profile | :plugins => plugins}}
          Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
            [environments: [{current_env, env}]]
        current_rel != nil ->
          rel = get_in(config, [:releases, current_rel])
          profile = rel.profile
          plugins = profile.plugins ++ [{unquote(name), unquote(opts)}]
          rel = %{rel | :profile => %{profile | :plugins => plugins}}
          Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
            [releases: [{current_rel, rel}]]
      end
    end
  end

  @doc """
  Set a config option within an environment or release definition.
  `set` takes a keyword list of one or more values to apply. An error
  will be raised if `set` is used outside of an environment or release definition,
  or if the config value being set does not exist.

  ## Usage

      environment :dev do
        set dev_mode: true
      end

  """
  defmacro set(opts) when is_list(opts) do
    quote do
      current_env = var!(current_env, Mix.Releases.Config)
      current_rel = var!(current_rel, Mix.Releases.Config)
      if current_env == nil && current_rel == nil do
        raise "cannot use set/1 outside of an environment or a release!"
      end
      config = Mix.Config.Agent.get(var!(config_agent, Mix.Releases.Config))
      cond do
        current_env != nil ->
          env = get_in(config, [:environments, current_env])
          env = Enum.reduce(unquote(opts), env, fn {k, v}, acc ->
            case Map.has_key?(acc.profile, k) do
              false ->
                raise "unknown environment config setting `#{k}`"
              true ->
                %{acc | :profile => Map.put(acc.profile, k, v)}
            end
          end)
          Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
            [environments: [{current_env, env}]]
        current_rel != nil ->
          rel = get_in(config, [:releases, current_rel])
          rel = Enum.reduce(unquote(opts), rel, fn
            {:version, v}, acc -> %{acc | :version => v}
            {:applications, v}, acc -> %{acc | :applications => acc.applications ++ v}
            {k, v}, acc ->
              case Map.has_key?(acc.profile, k) do
                false ->
                  raise "unknown release config setting `#{k}`"
                true ->
                  %{acc | :profile => Map.put(acc.profile, k, v)}
              end
          end)
          Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
            [releases: [{current_rel, rel}]]
      end
    end
  end

  @doc """
  Gets the current version of the given app and returns it as a string.
  If the app cannot be loaded, an error is raised. Intended to be used in conjunction
  with setting the version of a release definition, as shown below.

  ## Usage

      release :myapp do
        set version: current_version(:myapp)
      end

  """
  defmacro current_version(app) do
    quote do
      unless is_atom(unquote(app)) do
        raise "current_version argument must be an atom! got #{inspect unquote(app)}"
      end
      Application.load(unquote(app))
      case Application.spec(unquote(app)) do
        nil  -> raise "could not get current version of #{unquote(app)}, app could not be loaded"
        spec -> "#{Keyword.get(spec, :vsn)}"
      end
    end
  end

  @doc """
  Reads and validates a string containing the contents of a config file.
  If an error occurs during reading, a `Mix.Releases.Config.LoadError` will be raised.
  """
  @spec read_string!(String.t) :: Config.t | no_return
  def read_string!(contents) do
    {config, binding} = Code.eval_string(contents)

    config = case List.keyfind(binding, {:config_agent, Mix.Releases.Config}, 0) do
              {_, agent} -> get_config_and_stop_agent(agent)
              nil        -> config
            end

    config = to_struct(config)
    validate!(config)
    config
  rescue
    e in [LoadError] -> reraise(e, System.stacktrace)
    e -> reraise(LoadError, [file: "nofile", error: e], System.stacktrace)
  end

  @doc """
  Reads and validates a given configuration file.
  If the file does not exist, or an error occurs, a `Mix.Releases.Config.LoadError` will be raised.
  """
  @spec read!(String.t) :: Config.t | no_return
  def read!(file) do
    read_string!(File.read!(file))
  rescue
    e in [LoadError] -> reraise(LoadError, [file: file, error: e.error], System.stacktrace)
    e -> reraise(LoadError, [file: file, error: e], System.stacktrace)
  end

  @spec validate!(__MODULE__.t) :: true | no_return
  def validate!(%__MODULE__{:releases => []}) do
    raise ArgumentError,
      "expected release config to have at least one release defined"
  end
  def validate!(%__MODULE__{} = config) do
    environments = Map.to_list(config.environments)
    releases = Map.to_list(config.releases)
    profiles = Enum.map(releases ++ environments, fn {_, %{:profile => profile}} -> profile end)
    for profile <- profiles do
      for override <- (profile.overrides || []) do
        case override do
          {app, path} when is_atom(app) and is_binary(path) ->
            :ok
          value ->
            raise ArgumentError,
              "expected override to be an app name and path, but got: #{inspect value}"
        end
      end
      for overlay <- (profile.overlays || []) do
        case overlay do
          {op, opt} when is_atom(op) and is_binary(opt) ->
            :ok
          {op, opt1, opt2} when is_atom(op) and is_binary(opt1) and is_binary(opt2) ->
            :ok
          value ->
            raise ArgumentError,
              "expected overlay to be an overlay type and options, but got: #{inspect value}"
        end
      end
      cond do
        is_nil(profile.overlay_vars) ->
          :ok
        is_list(profile.overlay_vars) && length(profile.overlay_vars) > 0 && Keyword.keyword?(profile.overlay_vars) ->
          :ok
        is_list(profile.overlay_vars) && length(profile.overlay_vars) == 0 ->
          :ok
        :else ->
          raise ArgumentError,
            "expected overlay_vars to be a keyword list, but got: #{inspect profile.overlay_vars}"
      end
      paths_valid? = is_nil(profile.code_paths) || Enum.all?(profile.code_paths, &is_binary/1)
      cond do
        not is_nil(profile.dev_mode) and not is_boolean(profile.dev_mode) ->
          raise ArgumentError,
            "expected :dev_mode to be a boolean, but got: #{inspect profile.dev_mode}"
        not paths_valid? ->
          raise ArgumentError,
            "expected :code_paths to be a list of strings, but got: #{inspect profile.code_paths}"
        not is_nil(profile.vm_args) and not is_binary(profile.vm_args) ->
          raise ArgumentError,
            "expected :vm_args to be nil or a path string, but got: #{inspect profile.vm_args}"
        not is_nil(profile.sys_config) and not is_binary(profile.sys_config) ->
          raise ArgumentError,
            "expected :sys_config to be nil or a path string, but got: #{inspect profile.sys_config}"
        not is_nil(profile.include_erts) and
        not is_boolean(profile.include_erts) and
        not is_binary(profile.include_erts) ->
          raise ArgumentError,
            "expected :include_erts to be boolean or a path string, but got: #{inspect profile.include_erts}"
        not is_nil(profile.include_src) and
        not is_boolean(profile.include_src) and
        not is_binary(profile.include_src) ->
          raise ArgumentError,
            "expected :include_src to be boolean, but got: #{inspect profile.include_src}"
        not is_nil(profile.include_system_libs) and
        not is_boolean(profile.include_system_libs) and
        not is_binary(profile.include_system_libs) ->
          raise ArgumentError,
            "expected :include_system_libs to be boolean or a path string, but got: #{inspect profile.include_system_libs}"
        not is_nil(profile.erl_opts) and not is_binary(profile.erl_opts) ->
          raise ArgumentError,
            "expected :erl_opts to be a string, but got: #{inspect profile.erl_opts}"
        not is_nil(profile.run_erl_env) and not is_binary(profile.run_erl_env) ->
          raise ArgumentError,
            "expected :run_erl_env to be a string, but got: #{inspect profile.run_erl_env}"
        not is_nil(profile.strip_debug_info) and not is_boolean(profile.strip_debug_info) ->
          raise ArgumentError,
            "expected :strip_debug_info to be a boolean, but got: #{inspect profile.strip_debug_info}"
        not is_nil(profile.pre_configure_hook) and not is_binary(profile.pre_configure_hook) ->
          raise ArgumentError,
            "expected :pre_configure_hook to be nil or a path string, but got: #{inspect profile.pre_configure_hook}"
        not is_nil(profile.pre_start_hook) and not is_binary(profile.pre_start_hook) ->
          raise ArgumentError,
            "expected :pre_start_hook to be nil or a path string, but got: #{inspect profile.pre_start_hook}"
        not is_nil(profile.post_start_hook) and not is_binary(profile.post_start_hook) ->
          raise ArgumentError,
            "expected :post_start_hook to be nil or a path string, but got: #{inspect config.post_start_hook}"
        not is_nil(profile.pre_stop_hook) and not is_binary(profile.pre_stop_hook) ->
          raise ArgumentError,
            "expected :pre_stop_hook to be nil or a path string, but got: #{inspect profile.pre_stop_hook}"
        not is_nil(profile.post_stop_hook) and not is_binary(profile.post_stop_hook) ->
          raise ArgumentError,
            "expected :post_stop_hook to be nil or a path string, but got: #{inspect profile.post_stop_hook}"
        not is_nil(profile.pre_upgrade_hook) and not is_binary(profile.pre_upgrade_hook) ->
          raise ArgumentError,
            "expected :pre_upgrade_hook to be nil or a path string, but got: #{inspect profile.pre_upgrade_hook}"
        not is_nil(profile.post_upgrade_hook) and not is_binary(profile.post_upgrade_hook) ->
          raise ArgumentError,
            "expected :post_upgrade_hook to be nil or a path string, but got: #{inspect profile.post_upgrade_hook}"
        not is_nil(profile.pre_configure_hooks) and not is_binary(profile.pre_configure_hooks) ->
          raise ArgumentError,
            "expected :pre_configure_hooks to be nil or a path string, but got: #{inspect profile.pre_configure_hooks}"
        not is_nil(profile.pre_start_hooks) and not is_binary(profile.pre_start_hooks) ->
          raise ArgumentError,
            "expected :pre_start_hooks to be nil or a path string, but got: #{inspect profile.pre_start_hooks}"
        not is_nil(profile.post_start_hooks) and not is_binary(profile.post_start_hooks) ->
          raise ArgumentError,
            "expected :post_start_hooks to be nil or a path string, but got: #{inspect config.post_start_hooks}"
        not is_nil(profile.pre_stop_hooks) and not is_binary(profile.pre_stop_hooks) ->
          raise ArgumentError,
            "expected :pre_stop_hooks to be nil or a path string, but got: #{inspect profile.pre_stop_hooks}"
        not is_nil(profile.post_stop_hooks) and not is_binary(profile.post_stop_hooks) ->
          raise ArgumentError,
            "expected :post_stop_hooks to be nil or a path string, but got: #{inspect profile.post_stop_hooks}"
        not is_nil(profile.pre_upgrade_hooks) and not is_binary(profile.pre_upgrade_hooks) ->
          raise ArgumentError,
            "expected :pre_upgrade_hooks to be nil or a path string, but got: #{inspect profile.pre_upgrade_hooks}"
        not is_nil(profile.post_upgrade_hooks) and not is_binary(profile.post_upgrade_hooks) ->
          raise ArgumentError,
            "expected :post_upgrade_hooks to be nil or a path string, but got: #{inspect profile.post_upgrade_hooks}"
        :else ->
          true
      end
    end
    true
  end
  def validate!(config) do
    raise ArgumentError,
      "expected release config to be a struct, instead got: #{inspect config}"
  end

  defp get_config_and_stop_agent(agent) do
    config = Mix.Config.Agent.get(agent)
    Mix.Config.Agent.stop(agent)
    config
  end

  defp to_struct(config) when is_list(config) do
    case Keyword.keyword?(config) do
      false ->
        raise LoadError, message: "invalid config term, expected keyword list: #{inspect config}"
      true  ->
        default_env = Keyword.get(config, :default_environment)
        default_release = Keyword.get(config, :default_release)
        %__MODULE__{default_environment: default_env, default_release: default_release}
        |> to_struct(:environments, Keyword.get(config, :environments, []))
        |> to_struct(:releases, Keyword.get(config, :releases, []))
    end
  end

  defp to_struct(config, :environments, []) do
    %{config | :environments => %{default: Environment.new(:default)}}
  end
  defp to_struct(config, :environments, envs) do
    Enum.reduce(envs, config, fn {name, env}, acc ->
      %{acc | :environments => Map.put(acc.environments, name, env)}
    end)
  end
  defp to_struct(_config, :releases, []) do
    raise LoadError, message: "you must provide at least one release definition"
  end
  defp to_struct(config, :releases, rs) do
    Enum.reduce(rs, config, fn {name, rel}, acc ->
      %{acc | :releases => Map.put(acc.releases, name, rel)}
    end)
  end

end
