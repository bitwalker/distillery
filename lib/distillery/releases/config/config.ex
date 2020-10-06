defmodule Distillery.Releases.Config do
  @moduledoc """
  Responsible for parsing the release configuration file.
  """

  alias Distillery.Releases.{Release, Environment}
  alias Distillery.Releases.Config.LoadError

  defstruct environments: %{},
            releases: %{},
            default_release: :default,
            default_environment: :default,
            selected_release: :default,
            selected_environment: :default,
            is_upgrade: false,
            # the version to upgrade from (if applicable)
            upgrade_from: :latest

  @type t :: %__MODULE__{
          environments: map(),
          releases: map(),
          default_release: atom(),
          default_environment: atom(),
          selected_release: atom(),
          selected_environment: atom(),
          is_upgrade: boolean(),
          upgrade_from: :latest | String.t()
        }

  defmacro __using__(opts) do
    quote do
      import Distillery.Releases.Config

      opts = unquote(opts)

      var!(config, Distillery.Releases.Config) = %{
        environments: [],
        releases: [],
        default_release: Keyword.get(opts, :default_release, :default),
        default_environment: Keyword.get(opts, :default_environment, :default)
      }

      var!(current_env, Distillery.Releases.Config) = nil
      var!(current_rel, Distillery.Releases.Config) = nil
    end
  end

  @doc false
  @spec get() :: {:ok, t} | {:error, {:config, :not_found | String.t()}}
  @spec get(Keyword.t()) :: {:ok, t} | {:error, {:config, :not_found | String.t()}}
  def get(opts \\ []) do
    config_path = Path.join([File.cwd!(), "rel", "config.exs"])

    case File.exists?(config_path) do
      true ->
        base_config =
          try do
            read!(config_path)
          rescue
            e in [Config.LoadError] ->
              file = Path.relative_to_cwd(e.file)
              message = Exception.message(e)
              message = String.replace(message, "nofile", file)
              {:error, {:config, message}}
          end

        case base_config do
          {:error, _} = err ->
            err

          _ ->
            environments =
              base_config.environments
              |> Enum.map(fn {name, %{profile: profile} = e} ->
                executable_opts = get_opt(opts, :exec_opts, transient: false)

                executable =
                  case get_opt(opts, :executable, profile.executable) do
                    false ->
                      Keyword.put(executable_opts, :enabled, false)

                    true ->
                      Keyword.put(executable_opts, :enabled, true)

                    opts when is_list(opts) ->
                      Keyword.merge(executable_opts, opts)
                  end

                profile =
                  profile
                  |> Map.put(:dev_mode, get_opt(opts, :dev_mode, profile.dev_mode))
                  |> Map.put(:executable, executable)
                  |> Map.put(:erl_opts, get_opt(opts, :erl_opts, profile.erl_opts))
                  |> Map.put(:run_erl_env, get_opt(opts, :run_erl_env, profile.run_erl_env))

                {name, %{e | :profile => profile}}
              end)
              |> Map.new()

            updated_config =
              base_config
              |> Map.put(:environments, environments)
              |> Map.put(:is_upgrade, Keyword.fetch!(opts, :is_upgrade))
              |> Map.put(:upgrade_from, Keyword.fetch!(opts, :upgrade_from))
              |> Map.put(:selected_environment, Keyword.fetch!(opts, :selected_environment))
              |> Map.put(:selected_release, Keyword.fetch!(opts, :selected_release))

            {:ok, updated_config}
        end

      false ->
        {:error, {:config, :not_found}}
    end
  end

  defp get_opt(opts, key, default), do: Keyword.get(opts, key, default)

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
      name = unquote(name)

      unless is_atom(name) do
        raise "environment name must be an atom! got #{inspect(name)}"
      end

      env = Environment.new(name)
      conf = var!(config, Distillery.Releases.Config)
      var!(config, Distillery.Releases.Config) = put_in(conf, [:environments, name], env)
      var!(current_env, Distillery.Releases.Config) = name
      unquote(block)
      var!(current_env, Distillery.Releases.Config) = nil
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
      end

  """
  defmacro release(name, do: block) do
    quote do
      name = unquote(name)

      unless is_atom(name) do
        raise "release name must be an atom! got #{inspect(name)}"
      end

      rel = Release.new(name, unquote(@default_release_version), [])

      conf = var!(config, Distillery.Releases.Config)
      var!(config, Distillery.Releases.Config) = put_in(conf, [:releases, name], rel)
      var!(current_rel, Distillery.Releases.Config) = name
      unquote(block)
      var!(current_rel, Distillery.Releases.Config) = nil
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
    name =
      case name do
        n when is_atom(n) -> n
        {:__aliases__, _, module_parts} -> Module.concat(module_parts)
      end

    quote do
      name = unquote(name)
      plugin_opts = unquote(opts)
      current_env = var!(current_env, Distillery.Releases.Config)
      current_rel = var!(current_rel, Distillery.Releases.Config)

      if current_env == nil && current_rel == nil do
        raise "cannot use plugin/1 outside of an environment or a release!"
      end

      case :code.which(name) do
        :non_existing ->
          raise "cannot load plugin #{unquote(name)}, no such module could be found"

        _ ->
          :code.ensure_modules_loaded([name])
      end

      conf = var!(config, Distillery.Releases.Config)

      new_conf =
        cond do
          current_env != nil ->
            env = get_in(conf, [:environments, current_env])
            profile = env.profile
            plugins = profile.plugins ++ [{name, plugin_opts}]
            env = %{env | :profile => %{profile | :plugins => plugins}}

            put_in(conf, [:environments, current_env], env)

          current_rel != nil ->
            rel = get_in(conf, [:releases, current_rel])
            profile = rel.profile
            plugins = profile.plugins ++ [{name, plugin_opts}]
            rel = %{rel | :profile => %{profile | :plugins => plugins}}

            put_in(conf, [:releases, current_rel], rel)
        end

      var!(config, Distillery.Releases.Config) = new_conf
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
      current_env = var!(current_env, Distillery.Releases.Config)
      current_rel = var!(current_rel, Distillery.Releases.Config)

      if current_env == nil && current_rel == nil do
        raise "cannot use set/1 outside of an environment or a release!"
      end

      set_opts = unquote(opts)

      conf = var!(config, Distillery.Releases.Config)

      new_conf =
        cond do
          current_env != nil ->
            env = get_in(conf, [:environments, current_env])

            env =
              Enum.reduce(set_opts, env, fn {k, v}, acc ->
                case Map.has_key?(acc.profile, k) do
                  false ->
                    raise "unknown environment config setting `#{k}`"

                  true ->
                    %{acc | :profile => Map.put(acc.profile, k, v)}
                end
              end)

            put_in(conf, [:environments, current_env], env)

          current_rel != nil ->
            rel = get_in(conf, [:releases, current_rel])

            rel =
              Enum.reduce(set_opts, rel, fn
                {:version, v}, acc ->
                  %{acc | :version => v}

                {:applications, v}, acc ->
                  %{acc | :applications => acc.applications ++ v}

                {k, v}, acc ->
                  case Map.has_key?(acc.profile, k) do
                    false ->
                      raise "unknown release config setting `#{k}`"

                    true ->
                      %{acc | :profile => Map.put(acc.profile, k, v)}
                  end
              end)

            put_in(conf, [:releases, current_rel], rel)
        end

      var!(config, Distillery.Releases.Config) = new_conf
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
      app = unquote(app)

      unless is_atom(app) do
        raise "current_version argument must be an atom! got #{inspect(app)}"
      end

      Application.load(app)

      case Application.spec(app) do
        nil ->
          raise "could not get current version of #{app}, app could not be loaded"

        spec ->
          "#{Keyword.get(spec, :vsn)}"
      end
    end
  end

  @doc """
  Reads and validates a string containing the contents of a config file.
  If an error occurs during reading, a `Distillery.Releases.Config.LoadError` will be raised.
  """
  @spec read_string!(String.t()) :: t() | no_return
  def read_string!(contents) do
    {config, binding} = Code.eval_string(contents)

    config =
      case List.keyfind(binding, {:config, Distillery.Releases.Config}, 0) do
        {_, conf} ->
          conf

        nil ->
          config
      end

    config = to_struct(config)
    validate!(config)
    config
  rescue
    e in [LoadError] ->
      reraise(e, __STACKTRACE__)

    e ->
      reraise(LoadError, [file: "nofile", error: e], __STACKTRACE__)
  end

  @doc """
  Reads and validates a given configuration file.
  If the file does not exist, or an error occurs, a `Distillery.Releases.Config.LoadError` will be raised.
  """
  @spec read!(String.t()) :: t() | no_return
  def read!(file) do
    read_string!(File.read!(file))
  rescue
    e in [LoadError] ->
      reraise(LoadError, [file: file, error: e.error], __STACKTRACE__)

    e ->
      reraise(LoadError, [file: file, error: e], __STACKTRACE__)
  end

  @doc """
  Validates a `%Config{}` struct.
  If the struct is not valid, an `ArgumentError` is raised. If valid, returns `true`.
  """
  @spec validate!(__MODULE__.t()) :: true | no_return
  def validate!(%__MODULE__{:releases => []}) do
    raise ArgumentError, "expected release config to have at least one release defined"
  end

  def validate!(%__MODULE__{} = config) do
    environments = Map.to_list(config.environments)
    releases = Map.to_list(config.releases)
    profiles = Enum.map(releases ++ environments, fn {_, %{:profile => profile}} -> profile end)

    for profile <- profiles do
      for override <- profile.overrides || [] do
        case override do
          {app, path} when is_atom(app) and is_binary(path) ->
            :ok

          value ->
            raise ArgumentError,
                  "expected override to be an app name and path, but got: #{inspect(value)}"
        end
      end

      for overlay <- profile.overlays || [] do
        case overlay do
          {op, opt} when is_atom(op) and is_binary(opt) ->
            :ok

          {op, opt1, opt2} when is_atom(op) and is_binary(opt1) and is_binary(opt2) ->
            :ok

          value ->
            raise ArgumentError,
                  "expected overlay to be an overlay type and options, but got: #{inspect(value)}"
        end
      end

      cond do
        is_nil(profile.overlay_vars) ->
          :ok

        is_list(profile.overlay_vars) && length(profile.overlay_vars) > 0 &&
            Keyword.keyword?(profile.overlay_vars) ->
          :ok

        is_list(profile.overlay_vars) && length(profile.overlay_vars) == 0 ->
          :ok

        :else ->
          raise ArgumentError,
                "expected overlay_vars to be a keyword list, but got: #{
                  inspect(profile.overlay_vars)
                }"
      end

      cond do
        not is_nil(profile.dev_mode) and not is_boolean(profile.dev_mode) ->
          raise ArgumentError,
                "expected :dev_mode to be a boolean, but got: #{inspect(profile.dev_mode)}"

        not is_nil(profile.vm_args) and not is_binary(profile.vm_args) ->
          raise ArgumentError,
                "expected :vm_args to be nil or a path string, but got: #{
                  inspect(profile.vm_args)
                }"

        not is_nil(profile.sys_config) and not is_binary(profile.sys_config) ->
          raise ArgumentError,
                "expected :sys_config to be nil or a path string, but got: #{
                  inspect(profile.sys_config)
                }"

        not is_nil(profile.include_erts) and not is_boolean(profile.include_erts) and
            not is_binary(profile.include_erts) ->
          raise ArgumentError,
                "expected :include_erts to be boolean or a path string, but got: #{
                  inspect(profile.include_erts)
                }"

        not is_nil(profile.include_src) and not is_boolean(profile.include_src) and
            not is_binary(profile.include_src) ->
          raise ArgumentError,
                "expected :include_src to be boolean, but got: #{inspect(profile.include_src)}"

        not is_nil(profile.include_system_libs) and not is_boolean(profile.include_system_libs) and
            not is_binary(profile.include_system_libs) ->
          raise ArgumentError,
                "expected :include_system_libs to be boolean or a path string, but got: #{
                  inspect(profile.include_system_libs)
                }"

        not is_nil(profile.erl_opts) and not is_binary(profile.erl_opts) ->
          raise ArgumentError,
                "expected :erl_opts to be a string, but got: #{inspect(profile.erl_opts)}"

        not is_nil(profile.run_erl_env) and not is_binary(profile.run_erl_env) ->
          raise ArgumentError,
                "expected :run_erl_env to be a string, but got: #{inspect(profile.run_erl_env)}"

        not is_nil(profile.strip_debug_info) and not is_boolean(profile.strip_debug_info) ->
          raise ArgumentError,
                "expected :strip_debug_info to be a boolean, but got: #{
                  inspect(profile.strip_debug_info)
                }"

        not is_nil(profile.pre_configure_hooks) and not is_binary(profile.pre_configure_hooks) ->
          raise ArgumentError,
                "expected :pre_configure_hooks to be nil or a path string, but got: #{
                  inspect(profile.pre_configure_hooks)
                }"

        not is_nil(profile.post_configure_hooks) and not is_binary(profile.post_configure_hooks) ->
          raise ArgumentError,
                "expected :post_configure_hooks to be nil or a path string, but got: #{
                  inspect(profile.post_configure_hooks)
                }"

        not is_nil(profile.pre_start_hooks) and not is_binary(profile.pre_start_hooks) ->
          raise ArgumentError,
                "expected :pre_start_hooks to be nil or a path string, but got: #{
                  inspect(profile.pre_start_hooks)
                }"

        not is_nil(profile.post_start_hooks) and not is_binary(profile.post_start_hooks) ->
          raise ArgumentError,
                "expected :post_start_hooks to be nil or a path string, but got: #{
                  inspect(profile.post_start_hooks)
                }"

        not is_nil(profile.pre_stop_hooks) and not is_binary(profile.pre_stop_hooks) ->
          raise ArgumentError,
                "expected :pre_stop_hooks to be nil or a path string, but got: #{
                  inspect(profile.pre_stop_hooks)
                }"

        not is_nil(profile.post_stop_hooks) and not is_binary(profile.post_stop_hooks) ->
          raise ArgumentError,
                "expected :post_stop_hooks to be nil or a path string, but got: #{
                  inspect(profile.post_stop_hooks)
                }"

        not is_nil(profile.pre_upgrade_hooks) and not is_binary(profile.pre_upgrade_hooks) ->
          raise ArgumentError,
                "expected :pre_upgrade_hooks to be nil or a path string, but got: #{
                  inspect(profile.pre_upgrade_hooks)
                }"

        not is_nil(profile.post_upgrade_hooks) and not is_binary(profile.post_upgrade_hooks) ->
          raise ArgumentError,
                "expected :post_upgrade_hooks to be nil or a path string, but got: #{
                  inspect(profile.post_upgrade_hooks)
                }"

        :else ->
          true
      end
    end

    true
  end

  def validate!(config) do
    raise ArgumentError, "expected release config to be a struct, instead got: #{inspect(config)}"
  end

  defp to_struct(config) when is_map(config) do
    default_env = Map.get(config, :default_environment)
    default_release = Map.get(config, :default_release)

    %__MODULE__{default_environment: default_env, default_release: default_release}
    |> to_struct(:environments, Map.get(config, :environments, []))
    |> to_struct(:releases, Map.get(config, :releases, []))
  end

  defp to_struct(config) do
    raise LoadError, message: "invalid config term, expected map: #{inspect(config)}"
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
