defmodule Mix.Releases.Release do
  @moduledoc """
  Represents metadata about a release
  """
  alias Mix.Releases.{App, Profile, Overlays}

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
      dev_mode: false,
      include_erts: true,
      include_src: false,
      include_system_libs: true,
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
end
