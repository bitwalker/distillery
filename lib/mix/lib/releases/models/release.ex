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
    profile: %Profile{
      code_paths: [], # additional code paths to search
      erl_opts: [],
      dev_mode: false,
      include_erts: true, # false | path: "path/to/erts"
      include_src: false, # true
      include_system_libs: true, # false | path: "path/to/libs"
      strip_debug_info: true, # false
      overlay_vars: [],
      overlays: [],
      overrides: [
        # During development its often the case that you want to substitute the app
        # that you are working on for a 'production' version of an app. You can
        # explicitly tell Mix to override all versions of an app that you specify
        # with an app in an arbitrary directory. Mix will then symlink that app
        # into the release in place of the specified app. be aware though that Mix
        # will check your app for consistancy so it should be a normal OTP app and
        # already be built.
      ]
    }

  def new(name, version, apps \\ []) do
    definition = %__MODULE__{name: name, version: version}
    %{definition | :applications => definition.applications ++ apps}
  end
end
