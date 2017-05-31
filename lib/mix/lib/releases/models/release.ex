defmodule Mix.Releases.Release do
  @moduledoc """
  Represents metadata about a release
  """
  alias Mix.Releases.{App, Profile, Overlays, Config, Utils, Environment, Logger}

  defstruct name: nil,
    version: "0.1.0",
    applications: [
      :elixir, # required for elixir apps
      :iex, # included so the elixir shell works
      :sasl # required for upgrades
      # can also use `app_name: type`, as in `some_dep: load`,
      # to only load the application, not start it
    ],
    output_dir: nil,
    is_upgrade: false,
    upgrade_from: :latest,
    resolved_overlays: [],
    profile: %Profile{
      code_paths: [],
      erl_opts: "",
      run_erl_env: "",
      exec_opts: [transient: false],
      dev_mode: false,
      include_erts: true,
      include_src: false,
      include_system_libs: true,
      included_configs: [],
      strip_debug_info: false,
      plugins: [],
      overlay_vars: [],
      overlays: [],
      commands: [],
      overrides: []
    }

  @type t :: %__MODULE__{
    name: atom(),
    version: String.t,
    applications: list(atom | {atom, App.start_type} | App.t),
    is_upgrade: boolean,
    upgrade_from: nil | String.t,
    resolved_overlays: [Overlays.overlay],
    profile: Profile.t
  }

  @doc """
  Creates a new Release with the given name, version, and applications.
  """
  @spec new(atom(), String.t) :: __MODULE__.t
  @spec new(atom(), String.t, [atom()]) :: __MODULE__.t
  def new(name, version, apps \\ []) do
    build_path = Mix.Project.build_path
    output_dir = Path.relative_to_cwd(Path.join([build_path, "rel", "#{name}"]))
    definition = %__MODULE__{name: name, version: version}
    profile    = definition.profile
    %{definition | :applications => definition.applications ++ apps,
                   :output_dir => output_dir,
                   :profile => %{profile | :output_dir => output_dir}}
  end

  @doc """
  Load a fully configured Release object given a release name and environment name.
  """
  @spec get(atom()) :: {:ok, __MODULE__.t} | {:error, term()}
  @spec get(atom(), atom()) :: {:ok, __MODULE__.t} | {:error, term()}
  @spec get(atom(), atom(), Keyword.t) :: {:ok, __MODULE__.t} | {:error, term()}
  def get(name, env \\ :default, opts \\ [])

  def get(name, env, opts) when is_atom(name) and is_atom(env) do
    # load release configuration
    default_opts = [
      selected_environment: env,
      selected_release: name,
      is_upgrade: Keyword.get(opts, :is_upgrade, false),
      upgrade_from: Keyword.get(opts, :upgrade_from, false)
    ]
    case Config.get(Keyword.merge(default_opts, opts)) do
      {:error, _} = err -> err
      {:ok, config} ->
        with {:ok, env} <- select_environment(config),
             {:ok, rel} <- select_release(config),
             rel        <- apply_environment(rel, env),
          do: apply_configuration(rel, config, false)
    end
  end

  @doc """
  Get the path at which the release tarball will be output
  """
  @spec archive_path(__MODULE__.t) :: String.t
  def archive_path(%__MODULE__{profile: %Profile{output_dir: output_dir} = p} = r) do
    cond do
      p.executable ->
        Path.join([output_dir, "bin", "#{r.name}.run"])
      :else ->
        Path.join([output_dir, "releases", "#{r.version}", "#{r.name}.tar.gz"])
    end
  end

  # Returns the environment that the provided Config has selected
  @doc false
  @spec select_environment(Config.t) :: {:ok, Environment.t} | {:error, :no_environments}
  def select_environment(%Config{selected_environment: :default, default_environment: :default} = c),
    do: select_environment(Map.fetch(c.environments, :default))
  def select_environment(%Config{selected_environment: :default, default_environment: name} = c),
    do: select_environment(Map.fetch(c.environments, name))
  def select_environment(%Config{selected_environment: name} = c),
    do: select_environment(Map.fetch(c.environments, name))
  def select_environment({:ok, _} = e), do: e
  def select_environment(_),            do: {:error, :missing_environment}

  # Returns the release that the provided Config has selected
  @doc false
  @spec select_release(Config.t) :: {:ok, Release.t} | {:error, :no_releases}
  def select_release(%Config{selected_release: :default, default_release: :default} = c),
    do: {:ok, List.first(Map.values(c.releases))}
  def select_release(%Config{selected_release: :default, default_release: name} = c),
    do: select_release(Map.fetch(c.releases, name))
  def select_release(%Config{selected_release: name} = c),
    do: select_release(Map.fetch(c.releases, name))
  def select_release({:ok, _} = r), do: r
  def select_release(_),            do: {:error, :missing_release}

  # Applies the environment settings to a release
  @doc false
  @spec apply_environment(__MODULE__.t, Environment.t) :: Release.t
  def apply_environment(%__MODULE__{profile: rel_profile} = r, %Environment{profile: env_profile}) do
    env_profile = Map.from_struct(env_profile)
    profile = Enum.reduce(env_profile, rel_profile, fn {k, v}, acc ->
      case v do
        ignore when ignore in [nil, []] -> acc
        _   -> Map.put(acc, k, v)
      end
    end)
    %{r | :profile => profile}
  end

  @doc false
  @spec validate_configuration(__MODULE__.t) :: :ok | {:error, term} | {:ok, warning :: String.t}
  def validate_configuration(%__MODULE__{version: _, profile: profile}) do
    with :ok <- Utils.validate_erts(profile.include_erts) do
      # Warn if not including ERTS when not obviously running in a dev configuration
      if profile.dev_mode == false and profile.include_erts == false do
        {:ok, "IMPORTANT: You have opted to *not* include the Erlang runtime system (ERTS).\n" <>
          "You must ensure that the version of Erlang this release is built with matches\n" <>
          "the version the release will be run with once deployed. It will fail to run otherwise."}
      else
        :ok
      end
    end
  end

  # Applies global configuration options to the release profile
  @doc false
  @spec apply_configuration(__MODULE__.t, Config.t) :: {:ok, __MODULE__.t} | {:error, term}
  @spec apply_configuration(__MODULE__.t, Config.t, log? :: boolean) :: {:ok, __MODULE__.t} | {:error, term}
  def apply_configuration(%__MODULE__{version: current_version, profile: profile} = release, %Config{} = config, log? \\ false) do
    config_path = case profile.config do
                    p when is_binary(p) -> p
                    _ -> Keyword.get(Mix.Project.config, :config_path)
                  end
    base_release = %{release | :profile => %{profile | :config => config_path}}
    release = check_cookie(base_release, log?)
    case Utils.get_apps(release) do
      {:error, _} = err -> err
      release_apps ->
        release = %{release | :applications => release_apps}
        case config.is_upgrade do
          true ->
            case config.upgrade_from do
              :latest ->
                upfrom = case Utils.get_release_versions(release.profile.output_dir) do
                  [] -> :no_upfrom
                  [^current_version, v|_] -> v
                  [v|_] -> v
                end
                case upfrom do
                  :no_upfrom ->
                    if log? do
                      Logger.warn "An upgrade was requested, but there are no " <>
                        "releases to upgrade from, no upgrade will be performed."
                    end
                    {:ok, %{release | :is_upgrade => false, :upgrade_from => nil}}
                  v ->
                    {:ok, %{release | :is_upgrade => true, :upgrade_from => v}}
                end
              ^current_version ->
                {:error, {:assembler, {:bad_upgrade_spec, :upfrom_is_current, current_version}}}
              version when is_binary(version) ->
                if log?, do: Logger.debug("Upgrading #{release.name} from #{version} to #{current_version}")
                upfrom_path = Path.join([release.profile.output_dir, "releases", version])
                case File.exists?(upfrom_path) do
                  false ->
                    {:error, {:assembler, {:bad_upgrade_spec, :doesnt_exist, version, upfrom_path}}}
                  true ->
                    {:ok, %{release | :is_upgrade => true, :upgrade_from => version}}
                end
            end
          false ->
            {:ok, release}
        end
    end
  end

  defp check_cookie(%__MODULE__{profile: %Profile{cookie: cookie} = profile} = release, log?) do
    cond do
      !cookie and log? ->
        Logger.warn "Attention! You did not provide a cookie for the erlang distribution protocol in rel/config.exs\n" <>
          "    For backwards compatibility, the release name will be used as a cookie, which is potentially a security risk!\n" <>
          "    Please generate a secure cookie and use it with `set cookie: <cookie>` in rel/config.exs.\n" <>
          "    This will be an error in a future release."
        %{release | :profile => %{profile | :cookie => release.name}}
      not is_atom(cookie) ->
        %{release | :profile => %{profile | :cookie => :"#{cookie}"}}
      log? and String.contains?(Atom.to_string(cookie), "insecure") ->
        Logger.warn "Attention! You have an insecure cookie for the erlang distribution protocol in rel/config.exs\n" <>
          "    This is probably because a secure cookie could not be auto-generated.\n" <>
          "    Please generate a secure cookie and use it with `set cookie: <cookie>` in rel/config.exs." <>
        release
      :else ->
        release
    end
  end

  @doc """
  Returns a list of all code_paths of all appliactions included in the release
  """
  @spec get_code_paths(__MODULE__.t) :: [charlist()]
  def get_code_paths(%__MODULE__{profile: %Profile{output_dir: output_dir}} = release) do
    release.applications
    |> Enum.flat_map(fn %App{name: name, vsn: version, path: path} ->
      lib_dir = Path.join([output_dir, "lib", "#{name}-#{version}", "ebin"])
      [String.to_charlist(lib_dir), String.to_charlist(Path.join(path, "ebin"))]
    end)
  end
end
