defmodule Distillery.Releases.Release do
  @moduledoc """
  Represents metadata about a release
  """
  alias Distillery.Releases.App
  alias Distillery.Releases.Profile
  alias Distillery.Releases.Overlays
  alias Distillery.Releases.Config
  alias Distillery.Releases.Utils
  alias Distillery.Releases.Environment
  alias Distillery.Releases.Shell

  defstruct name: nil,
            version: "0.1.0",
            applications: [
              # required for elixir apps
              :elixir,
              # included so the elixir shell works
              :iex,
              # required for Mix config provider
              :mix,
              # required for upgrades
              :sasl,
              # required for some command tooling
              :runtime_tools,
              # needed for config provider API
              :distillery
              # can also use `app_name: type`, as in `some_dep: load`,
              # to only load the application, not start it
            ],
            is_upgrade: false,
            upgrade_from: :latest,
            resolved_overlays: [],
            profile: %Profile{
              erl_opts: "",
              run_erl_env: "",
              executable: [enabled: false, transient: false],
              dev_mode: false,
              include_erts: true,
              include_src: false,
              include_system_libs: true,
              included_configs: [],
              config_providers: [],
              appup_transforms: [],
              strip_debug_info: false,
              plugins: [],
              overlay_vars: [],
              overlays: [],
              commands: [],
              overrides: []
            },
            env: nil

  @type t :: %__MODULE__{
          name: atom,
          version: String.t(),
          applications: list(atom | {atom, App.start_type()} | App.t()),
          is_upgrade: boolean,
          upgrade_from: nil | String.t() | :latest,
          resolved_overlays: [Overlays.overlay()],
          profile: Profile.t(),
          env: atom
        }

  @type app_resource ::
          {atom, app_version :: charlist}
          | {atom, app_version :: charlist, App.start_type()}
  @type resource ::
          {:release, {name :: charlist, version :: charlist}, {:erts, erts_version :: charlist},
           [app_resource]}

  @doc """
  Creates a new Release with the given name, version, and applications.
  """
  @spec new(atom, String.t()) :: t
  @spec new(atom, String.t(), [atom]) :: t
  def new(name, version, apps \\ []) do
    build_path = Mix.Project.build_path()
    output_dir = Path.relative_to_cwd(Path.join([build_path, "rel", "#{name}"]))
    definition = %__MODULE__{name: name, version: version}

    %__MODULE__{
      definition
      | applications: definition.applications ++ apps,
        profile: %Profile{definition.profile | output_dir: output_dir}
    }
  end

  @doc """
  Load a fully configured Release object given a release name and environment name.
  """
  @spec get(atom) :: {:ok, t} | {:error, term}
  @spec get(atom, atom) :: {:ok, t} | {:error, term}
  @spec get(atom, atom, Keyword.t()) :: {:ok, t} | {:error, term}
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
      {:error, _} = err ->
        err

      {:ok, config} ->
        with {:ok, env} <- select_environment(config),
             {:ok, rel} <- select_release(config),
             rel <- apply_environment(rel, env),
             do: apply_configuration(rel, config, false)
    end
  end

  @doc """
  Converts a Release struct to a release resource structure.

  The format of release resources is documented [in the Erlang manual](http://erlang.org/doc/design_principles/release_structure.html#res_file)
  """
  @spec to_resource(t) :: resource
  def to_resource(
        %__MODULE__{applications: apps, profile: %Profile{erts_version: erts}} = release
      ) do
    rel_name = Atom.to_charlist(release.name)
    rel_version = String.to_charlist(release.version)
    erts = String.to_charlist(erts)

    {
      :release,
      {rel_name, rel_version},
      {:erts, erts},
      for %App{name: name, vsn: vsn, start_type: start_type} <- apps do
        if is_nil(start_type) do
          {name, '#{vsn}'}
        else
          {name, '#{vsn}', start_type}
        end
      end
    }
  end

  @doc """
  Returns true if the release is executable
  """
  @spec executable?(t) :: boolean()
  def executable?(%__MODULE__{profile: %Profile{executable: false}}),
    do: false

  def executable?(%__MODULE__{profile: %Profile{executable: true}}),
    do: true

  def executable?(%__MODULE__{profile: %Profile{executable: e}}),
    do: Keyword.get(e, :enabled, false)

  @doc """
  Get the path to which release binaries will be output
  """
  @spec bin_path(t) :: String.t()
  def bin_path(%__MODULE__{profile: %Profile{output_dir: output_dir}}) do
    [output_dir, "bin"]
    |> Path.join()
    |> Path.expand()
  end

  @doc """
  Get the path to which versioned release data will be output
  """
  @spec version_path(t) :: String.t()
  def version_path(%__MODULE__{profile: %Profile{output_dir: output_dir}} = r) do
    [output_dir, "releases", "#{r.version}"]
    |> Path.join()
    |> Path.expand()
  end

  @doc """
  Get the path to which compiled applications will be output
  """
  @spec lib_path(t) :: String.t()
  def lib_path(%__MODULE__{profile: %Profile{output_dir: output_dir}}) do
    [output_dir, "lib"]
    |> Path.join()
    |> Path.expand()
  end

  @doc """
  Get the path to which the release tarball will be output
  """
  @spec archive_path(t) :: String.t()
  def archive_path(%__MODULE__{profile: %Profile{executable: e} = p} = r) when is_list(e) do
    if Keyword.get(e, :enabled, false) do
      Path.join([bin_path(r), "#{r.name}.run"])
    else
      archive_path(%__MODULE__{r | profile: %{p | executable: false}})
    end
  end

  def archive_path(%__MODULE__{profile: %Profile{executable: false}} = r) do
    Path.join([version_path(r), "#{r.name}.tar.gz"])
  end

  # Returns the environment that the provided Config has selected
  @doc false
  @spec select_environment(Config.t()) :: {:ok, Environment.t()} | {:error, :missing_environment}
  def select_environment(
        %Config{selected_environment: :default, default_environment: :default} = c
      ) do
    case Map.get(c.environments, :default) do
      nil ->
        {:error, :missing_environment}

      env ->
        {:ok, env}
    end
  end

  def select_environment(%Config{selected_environment: :default, default_environment: name} = c),
    do: select_environment(%Config{c | selected_environment: name})

  def select_environment(%{selected_environment: name} = c) do
    case Map.get(c.environments, name) do
      nil ->
        {:error, :missing_environment}

      env ->
        {:ok, env}
    end
  end

  # Returns the release that the provided Config has selected
  @doc false
  @spec select_release(Config.t()) :: {:ok, t} | {:error, :missing_release}
  def select_release(%Config{selected_release: :default, default_release: :default} = c),
    do: {:ok, List.first(Map.values(c.releases))}

  def select_release(%Config{selected_release: :default, default_release: name} = c),
    do: select_release(%Config{c | selected_release: name})

  def select_release(%Config{selected_release: name} = c) do
    case Map.get(c.releases, name) do
      nil ->
        {:error, :missing_release}

      release ->
        {:ok, release}
    end
  end

  # Applies the environment settings to a release
  @doc false
  @spec apply_environment(t, Environment.t()) :: t
  def apply_environment(%__MODULE__{profile: rel_profile} = r, %Environment{name: env_name} = env) do
    env_profile = Map.from_struct(env.profile)

    profile =
      Enum.reduce(env_profile, rel_profile, fn
        {:plugins, ps}, acc when ps not in [nil, []] ->
          # Merge plugins
          rel_plugins = Map.get(acc, :plugins, [])
          Map.put(acc, :plugins, rel_plugins ++ ps)
        {k, v}, acc ->
          case v do
            ignore when ignore in [nil, []] ->
              acc
            _ ->
              Map.put(acc, k, v)
          end
      end)

    %{r | :env => env_name, :profile => profile}
  end

  @doc false
  defdelegate validate(release), to: Distillery.Releases.Checks, as: :run

  # Applies global configuration options to the release profile
  @doc false
  @spec apply_configuration(t, Config.t()) :: {:ok, t} | {:error, term}
  @spec apply_configuration(t, Config.t(), log? :: boolean) :: {:ok, t} | {:error, term}
  def apply_configuration(%__MODULE__{} = release, %Config{} = config, log? \\ false) do
    profile = release.profile

    profile =
      case profile.config do
        p when is_binary(p) ->
          %{profile | config: p}

        _ ->
          %{profile | config: Keyword.get(Mix.Project.config(), :config_path)}
      end

    profile =
      case profile.include_erts do
        p when is_binary(p) ->
          case Utils.detect_erts_version(p) do
            {:error, _} = err ->
              throw(err)

            {:ok, vsn} ->
              %{profile | erts_version: vsn, include_system_libs: true}
          end

        true ->
          %{profile | erts_version: Utils.erts_version(), include_system_libs: true}

        _ ->
          %{profile | erts_version: Utils.erts_version(), include_system_libs: false}
      end

    profile =
      case profile.cookie do
        nil ->
          profile

        c when is_atom(c) ->
          profile

        c when is_binary(c) ->
          %{profile | cookie: String.to_atom(c)}

        c ->
          throw({:error, {:assembler, {:invalid_cookie, c}}})
      end

    release = %{release | profile: profile}

    release =
      case apps(release) do
        {:error, _} = err ->
          throw(err)

        apps ->
          %{release | applications: apps}
      end

    if config.is_upgrade do
      apply_upgrade_configuration(release, config, log?)
    else
      {:ok, release}
    end
  catch
    :throw, {:error, _} = err ->
      err
  end

  defp apply_upgrade_configuration(%__MODULE__{} = release, %Config{upgrade_from: :latest}, log?) do
    current_version = release.version

    upfrom =
      case Utils.get_release_versions(release.profile.output_dir) do
        [] ->
          :no_upfrom

        [^current_version, v | _] ->
          v

        [v | _] ->
          v
      end

    case upfrom do
      :no_upfrom ->
        if log? do
          Shell.warn(
            "An upgrade was requested, but there are no " <>
              "releases to upgrade from, no upgrade will be performed."
          )
        end

        {:ok, %{release | :is_upgrade => false, :upgrade_from => nil}}

      v ->
        {:ok, %{release | :is_upgrade => true, :upgrade_from => v}}
    end
  end

  defp apply_upgrade_configuration(%__MODULE__{version: v}, %Config{upgrade_from: v}, _log?) do
    {:error, {:assembler, {:bad_upgrade_spec, :upfrom_is_current, v}}}
  end

  defp apply_upgrade_configuration(
         %__MODULE__{name: name} = release,
         %Config{upgrade_from: v},
         log?
       ) do
    current_version = release.version

    if log?,
      do: Shell.debug("Upgrading #{name} from #{v} to #{current_version}")

    upfrom_path = Path.join([release.profile.output_dir, "releases", v])

    if File.exists?(upfrom_path) do
      {:ok, %{release | :is_upgrade => true, :upgrade_from => v}}
    else
      {:error, {:assembler, {:bad_upgrade_spec, :doesnt_exist, v, upfrom_path}}}
    end
  end

  @doc """
  Returns a list of all code_paths of all applications included in the release
  """
  @spec get_code_paths(t) :: [charlist]
  def get_code_paths(%__MODULE__{profile: %Profile{output_dir: output_dir}} = release) do
    release.applications
    |> Enum.flat_map(fn %App{name: name, vsn: version, path: path} ->
      lib_dir = Path.join([output_dir, "lib", "#{name}-#{version}", "ebin"])
      [String.to_charlist(lib_dir), String.to_charlist(Path.join(path, "ebin"))]
    end)
  end

  @doc """
  Gets a list of {app, vsn} tuples for the current release.

  An optional second parameter enables/disables debug logging of discovered apps.
  """
  @spec apps(t) :: [App.t()] | {:error, term}
  def apps(%__MODULE__{name: name, applications: apps} = release) do
    # The list of applications which have been _manually_ specified
    # to be part of this release - it is not required to be exhaustive
    apps =
      if Enum.member?(apps, name) do
        apps
      else
        cond do
          Mix.Project.umbrella?() ->
            # Nothing to do
            apps

          Mix.Project.config()[:app] == name ->
            # This is a non-umbrella project, with a release named the same as the app
            # Make sure the app is part of the release, or it makes no sense
            apps ++ [name]

          :else ->
            # The release is named something different, nothing to do
            apps
        end
      end

    # Validate listed apps
    for app <- apps do
      app_name =
        case app do
          {name, start_type} ->
            if App.valid_start_type?(start_type) do
              name
            else
              throw({:invalid_start_type, name, start_type})
            end

          name ->
            name
        end

      case validate_app(app_name) do
        :ok ->
          :ok

        {:error, reason} ->
          throw({:invalid_app, app_name, reason})
      end
    end

    # A graph of relationships between applications
    dg = :digraph.new([:acyclic, :protected])
    as = :ets.new(name, [:set, :protected])

    try do
      # Add app relationships to the graph
      add_apps(dg, as, apps)

      # Perform topological sort
      result =
        case :digraph_utils.topsort(dg) do
          false ->
            raise "Unable to topologically sort the dependency graph!"

          sorted ->
            sorted
            |> Enum.map(fn a -> elem(hd(:ets.lookup(as, a)), 1) end)
            |> Enum.map(&correct_app_path_and_vsn(&1, release))
        end

      print_discovered_apps(result)

      result
    after
      :ets.delete(as)
      :digraph.delete(dg)
    end
  catch
    :throw, err ->
      {:error, {:apps, err}}
  end

  defp add_apps(_dg, _as, []),
    do: :ok

  defp add_apps(dg, as, [app | apps]) do
    add_app(dg, as, nil, app)
    add_apps(dg, as, apps)
  end

  defp add_app(dg, as, parent, {name, start_type}) do
    case :digraph.vertex(dg, name) do
      false ->
        case validate_app(name) do
          :ok ->
            # Haven't seen this app yet, and it is not excluded
            do_add_app(dg, as, parent, App.new(name, start_type))
          error ->
            error
        end
      _ ->
        # Already visited
        :ok
    end
  end
  defp add_app(dg, as, parent, name) do
    add_app(dg, as, parent, {name, nil})
  end

  defp do_add_app(dg, as, nil, app) do
    :digraph.add_vertex(dg, app.name)
    :ets.insert(as, {app.name, app})
    do_add_children(dg, as, app.name, app.applications ++ app.included_applications)
  end
  defp do_add_app(dg, as, parent, app) do
    :digraph.add_vertex(dg, app.name)
    :ets.insert(as, {app.name, app})
    case :digraph.add_edge(dg, parent, app.name) do
      {:error, reason} ->
        raise "edge from #{parent} to #{app.name} would result in cycle: #{inspect(reason)}"

      _ ->
        do_add_children(dg, as, app.name, app.applications ++ app.included_applications)
    end
  end

  defp do_add_children(_dg, _as, _parent, []),
    do: :ok

  defp do_add_children(dg, as, parent, [app | apps]) do
    add_app(dg, as, parent, app)
    do_add_children(dg, as, parent, apps)
  end

  defp correct_app_path_and_vsn(%App{} = app, %__MODULE__{profile: %Profile{include_erts: ie}})
       when ie in [true, false] do
    app
  end

  defp correct_app_path_and_vsn(%App{} = app, %__MODULE__{profile: %Profile{include_erts: p}}) do
    # Correct any ERTS libs which should be pulled from the correct
    # ERTS directory, not from the current environment.
    lib_dir = Path.expand(Path.join(p, "lib"))

    if Utils.is_erts_lib?(app.path) do
      case Path.wildcard(Path.join(lib_dir, "#{app.name}-*")) do
        [corrected_app_path | _] ->
          [_, corrected_app_vsn] =
            String.split(Path.basename(corrected_app_path), "-", trim: true)

          %App{app | vsn: corrected_app_vsn, path: corrected_app_path}

        _ ->
          throw({:apps, {:missing_required_lib, app.name, lib_dir}})
      end
    else
      app
    end
  end

  defp print_discovered_apps(apps) do
    Shell.debug("Discovered applications:")
    do_print_discovered_apps(apps)
  end

  defp do_print_discovered_apps([]), do: :ok

  defp do_print_discovered_apps([app | apps]) do
    where = Path.relative_to_cwd(app.path)
    Shell.debugf("  > #{Shell.colorf("#{app.name}-#{app.vsn}", :white)}")
    Shell.debugf("\n  |\n  |  from: #{where}\n")

    case app.applications do
      [] ->
        Shell.debugf("  |  applications: none\n")

      apps ->
        display_apps =
          apps
          |> Enum.map(&inspect/1)
          |> Enum.join("\n  |      ")

        Shell.debugf("  |  applications:\n  |      #{display_apps}\n")
    end

    case app.included_applications do
      [] ->
        Shell.debugf("  |  includes: none\n")

      included_apps ->
        display_apps =
          included_apps
          |> Enum.map(&inspect/1)
          |> Enum.join("\n  |  ")

        Shell.debugf("  |  includes:\n  |      #{display_apps}")
    end

    Shell.debugf("  |_____\n\n")
    do_print_discovered_apps(apps)
  end

  defp validate_app(app_name) do
    case Application.load(app_name) do
      :ok ->
        :ok

      {:error, {:already_loaded, _}} ->
        :ok

      error ->
        error
    end
  end
end
