defmodule Mix.Releases.Release do
  @moduledoc """
  Represents metadata about a release
  """
  alias Mix.Releases.Profile

  defstruct name: "",
    version: "0.1.0",
    applications: [
      :elixir, # required for elixir apps
      :iex, # included so the elixir shell works
      :sasl # required for upgrades
      # can also use `app_name: type`, as in `some_dep: load`,
      # to only load the application, not start it
    ],
    is_upgrade: false,
    upgrade_from: :latest,
    output_dir: nil,
    profile: %Profile{
      code_paths: [],
      erl_opts: "",
      dev_mode: false,
      include_erts: true,
      include_src: false,
      include_system_libs: true,
      strip_debug_info: true,
      overlay_vars: [],
      overlays: [],
      commands: [],
      overrides: []
    }

  def new(name, version, apps \\ []) do
    output_dir = Path.relative_to_cwd(Path.join("rel", "#{name}"))
    definition = %__MODULE__{name: name, version: version, output_dir: output_dir}
    %{definition | :applications => definition.applications ++ apps}
  end
end
