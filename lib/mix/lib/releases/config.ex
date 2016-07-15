defmodule Mix.Releases.Config do
  @moduledoc false

  defmodule LoadError do
    defexception [:file, :error]

    def message(%LoadError{file: file, error: error}) do
      "could not load release config #{Path.relative_to_cwd(file)}\n    " <>
        "#{Exception.format_banner(:error, error)}"
    end
  end

  defmodule ReleaseDefinition do
    defstruct name: "",
      version: "0.0.1",
      applications: [
        :iex, # included so the elixir shell works
        :sasl # required for upgrades
        # can also use `app_name: type`, as in `some_dep: load`,
        # to only load the application, not start it
      ]

    def new(name, version, apps \\ []) do
      definition = %__MODULE__{name: name, version: version}
      %{definition | :applications => definition.applications ++ apps}
    end
  end

  defstruct dev_mode: false,
            paths: [], # additional code paths to search
            vm_args: nil, # path to a custom vm.args
            sys_config: nil, # path to a custom sys.config
            include_erts: true, # false | path: "path/to/erts"
            include_src: false, # true
            include_system_libs: true, # false | path: "path/to/libs"
            strip_debug_info?: true, # false
            selected_release: :default, # the release being built
            upgrade_from: :default, # the release to upgrade from (if applicable)
            erl_opts: [],
            releases: [], # the releases to select from
            overrides: [
              # During development its often the case that you want to substitute the app
              # that you are working on for a 'production' version of an app. You can
              # explicitly tell Mix to override all versions of an app that you specify
              # with an app in an arbitrary directory. Mix will then symlink that app
              # into the release in place of the specified app. be aware though that Mix
              # will check your app for consistancy so it should be a normal OTP app and
              # already be built.
            ],
            overlay_vars: [
              # key: value
            ],
            overlays: [
              # copy: {from_path, to_path}
              # link: {from_path, to_path}
              # mkdir: path
              # template: {template_path, output_path}
            ],
            pre_start_hook: nil,
            post_start_hook: nil,
            pre_stop_hook: nil,
            post_stop_hook: nil

   defmacro __using__(_) do
     quote do
       import Mix.Releases.Config, only: [
         release: 2, release: 3, override: 2, overlay: 2, config: 1,
         version: 1
       ]
       {:ok, agent} = Mix.Config.Agent.start_link
       var!(config_agent, Mix.Releases.Config) = agent
     end
   end

   defmacro config(opts) when is_list(opts) do
     quote do
       Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
         [{:settings, unquote(opts)}]
     end
   end

   defmacro release(name, version, applications \\ []) do
     quote do
       Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
         [{:releases, [{unquote(name), [{unquote(version), unquote(applications)}]}]}]
     end
   end

   defmacro override(app, path) do
    quote do
      Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
        [{:overrides, [{unquote(app), unquote(path)}]}]
    end
   end

   defmacro overlay(type, opts) do
     quote do
       Mix.Config.Agent.merge var!(config_agent, Mix.Releases.Config),
         [{:overlays, [{unquote(type), unquote(opts)}]}]
     end
   end

   defmacro version(app) do
     quote do
       Application.load(unquote(app))
       case Application.spec(unquote(app)) do
         nil  -> raise ArgumentError, "could not load app #{unquote(app)}"
         spec -> Keyword.get(spec, :vsn)
       end
     end
   end

   @doc """
   Reads and validates a configuration file.
   `file` is the path to the configuration file to be read. If that file doesn't
   exist or if there's an error loading it, a `Mix.Releases.Config.LoadError` exception
   will be raised.
   """
   def read!(file) do
     try do
       {config, binding} = Code.eval_file(file)

       config = case List.keyfind(binding, {:config_agent, Mix.Releases.Config}, 0) do
                  {_, agent} -> get_config_and_stop_agent(agent)
                  nil        -> config
                end

       config = to_struct(config)
       validate!(config)
       config
     rescue
       e in [LoadError] -> reraise(e, System.stacktrace)
       e -> reraise(LoadError, [file: file, error: e], System.stacktrace)
     end
   end

   def validate!(%__MODULE__{:releases => []}) do
     raise ArgumentError,
       "expected release config to have at least one release defined"
   end
   def validate!(%__MODULE__{} = config) do
     for override <- config.overrides do
       case override do
         {app, path} when is_atom(app) and is_binary(path) ->
           :ok
         value ->
           raise ArgumentError,
             "expected override to be an app name and path, but got: #{inspect value}"
       end
     end
     for overlay <- config.overlays do
       case overlay do
         {op, opts} when is_atom(op) and is_list(opts) ->
           :ok
         value ->
           raise ArgumentError,
             "expected overlay to be an overlay type and options, but got: #{inspect value}"
       end
     end
     cond do
       is_list(config.overlay_vars) && length(config.overlay_vars) > 0 && Keyword.keyword?(config.overlay_vars) ->
         :ok
       is_list(config.overlay_vars) && length(config.overlay_vars) == 0 ->
         :ok
       :else ->
         raise ArgumentError,
           "expected overlay_vars to be a keyword list, but got: #{inspect config.overlay_vars}"
     end
     paths_valid? = Enum.all?(config.paths, &is_binary/1)
     cond do
       not is_boolean(config.dev_mode) ->
         raise ArgumentError,
           "expected :dev_mode to be a boolean, but got: #{inspect config.dev_mode}"
       not paths_valid? ->
         raise ArgumentError,
           "expected :paths to be a list of strings, but got: #{inspect config.paths}"
       not (is_nil(config.vm_args) or is_binary(config.vm_args)) ->
         raise ArgumentError,
           "expected :vm_args to be nil or a path string, but got: #{inspect config.vm_args}"
       not (is_nil(config.sys_config) or is_binary(config.sys_config)) ->
         raise ArgumentError,
           "expected :sys_config to be nil or a path string, but got: #{inspect config.sys_config}"
       not (is_boolean(config.include_erts) or is_binary(config.include_erts)) ->
         raise ArgumentError,
           "expected :include_erts to be boolean or a path string, but got: #{inspect config.include_erts}"
       not (is_boolean(config.include_src) or is_binary(config.include_src)) ->
         raise ArgumentError,
           "expected :include_src to be boolean, but got: #{inspect config.include_src}"
       not (is_boolean(config.include_system_libs) or is_binary(config.include_system_libs)) ->
         raise ArgumentError,
           "expected :include_system_libs to be boolean or a path string, but got: #{inspect config.include_system_libs}"
       not is_list(config.erl_opts) ->
         raise ArgumentError,
           "expected :erl_opts to be a list, but got: #{inspect config.erl_opts}"
       not is_boolean(config.strip_debug_info?) ->
         raise ArgumentError,
           "expected :strip_debug_info? to be a boolean, but got: #{inspect config.strip_debug_info?}"
       not (is_nil(config.pre_start_hook) or is_binary(config.pre_start_hook)) ->
         raise ArgumentError,
           "expected :pre_start_hook to be nil or a path string, but got: #{inspect config.pre_start_hook}"
       not (is_nil(config.post_start_hook) or is_binary(config.post_start_hook)) ->
         raise ArgumentError,
           "expected :post_start_hook to be nil or a path string, but got: #{inspect config.post_start_hook}"
       not (is_nil(config.pre_stop_hook) or is_binary(config.pre_stop_hook)) ->
         raise ArgumentError,
           "expected :pre_stop_hook to be nil or a path string, but got: #{inspect config.pre_stop_hook}"
       not (is_nil(config.post_stop_hook) or is_binary(config.post_stop_hook)) ->
         raise ArgumentError,
           "expected :post_stop_hook to be nil or a path string, but got: #{inspect config.post_stop_hook}"
       :else ->
         true
     end
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
       false -> to_struct(:default)
       true  ->
         %__MODULE__{}
         |> to_struct(:settings, Keyword.get(config, :settings, []))
         |> to_struct(:releases, Keyword.get(config, :releases, []))
         |> to_struct(:overrides, Keyword.get(config, :overrides, []))
         |> to_struct(:overlays, Keyword.get(config, :overlays, []))
     end
   end
   # If no config is given, generate a default release definition for the current project.
   # If the current project is an umbrella, generate a release which contains all applications
   # in the umbrella.
   defp to_struct(_) do
     current_project = Mix.Project.config
     case Mix.Project.umbrella?(current_project) do
       true ->
         apps_path = Keyword.fetch!(current_project, :apps_path)
         apps = get_umbrella_apps(apps_path)
         app = convert_to_name(Mix.Project.get!)
         version = "0.1.0"
         %__MODULE__{
           releases: [ReleaseDefinition.new(app, version, apps)]
         }
       false ->
         app = Keyword.fetch!(current_project, :app)
         version = Keyword.fetch!(current_project, :version)
         %__MODULE__{
           releases: [ReleaseDefinition.new(app, version, [app])]
         }
     end
   end

   defp to_struct(config, :settings, []), do: config
   defp to_struct(config, :settings, s) do
     %__MODULE__{
       config |
       :dev_mode => Keyword.get(s, :dev_mode, config.dev_mode),
       :paths => Keyword.get(s, :paths, config.paths),
       :vm_args => Keyword.get(s, :vm_args, config.vm_args),
       :sys_config => Keyword.get(s, :sys_config, config.sys_config),
       :include_erts => Keyword.get(s, :include_erts, config.include_erts),
       :include_src => Keyword.get(s, :include_erts, config.include_src),
       :erl_opts => Keyword.get(s, :erl_opts, config.erl_opts),
       :include_system_libs => Keyword.get(s, :include_system_libs, config.include_system_libs),
       :strip_debug_info? => Keyword.get(s, :strip_debug_info?, config.strip_debug_info?),
       :overlay_vars => Keyword.get(s, :overlay_vars, config.overlay_vars),
       :pre_start_hook => Keyword.get(s, :pre_start_hook, config.pre_start_hook),
       :post_start_hook => Keyword.get(s, :post_start_hook, config.post_start_hook),
       :pre_stop_hook => Keyword.get(s, :pre_stop_hook, config.pre_stop_hook),
       :post_stop_hook => Keyword.get(s, :post_stop_hook, config.post_stop_hook)
     }
   end
   defp to_struct(config, :releases, []), do: config
   defp to_struct(config, :releases, r) do
     releases = Enum.flat_map(r, fn
       {app, [{version, []}]}->
         [ReleaseDefinition.new(app, version, [app])]
       {app, [{version, apps}]} when is_list(apps) ->
         [ReleaseDefinition.new(app, version, Enum.uniq([app|apps]))]
       {app, versions} when is_list(versions) ->
         Enum.map(versions, fn
           {version, []} ->
             ReleaseDefinition.new(app, version)
           {version, apps} when is_list(apps) ->
             ReleaseDefinition.new(app, version, Enum.uniq([app|apps]))
         end)
     end)
     %__MODULE__{config | :releases => releases}
   end
   defp to_struct(config, :overrides, o) do
     %__MODULE__{config | :overrides => o}
   end
   defp to_struct(config, :overlays, o) do
     %__MODULE__{config | :overlays => o}
   end

   defp convert_to_name(module) when is_atom(module) do
     [name_str|_] = Module.split(module)
     Regex.split(~r/(?<word>[A-Z][^A-Z]*)/, name_str, on: [:word], include_captures: true, trim: true)
     |> Enum.map(&String.downcase/1)
     |> Enum.join("_")
     |> String.to_atom
   end

   defp get_umbrella_apps(apps_path) do
     Path.wildcard(Path.join(apps_path, "*"))
     |> Enum.map(fn path ->
       Mix.Project.in_project(:app, path, fn _mixfile ->
         Keyword.fetch!(Mix.Project.config, :app)
       end)
     end)
   end

end
