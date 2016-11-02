defmodule Mix.Releases.Profile do
  @moduledoc """
  Represents the configuration profile for a specific environment and release.
  More generally, a release has a profile, as does an environment, and
  when determining the configuration for a release in a given environment, the
  environment profile overrides the release profile.
  """
  defstruct output_dir: nil,
    vm_args: nil, # path to a custom vm.args
    cookie: nil,
    config: nil, # path to a custom config.exs
    sys_config: nil, # path to a custom sys.config
    code_paths: nil, # list of additional code paths to search
    erl_opts: nil, # string to be passed to erl
    dev_mode: nil, # boolean
    include_erts: nil, # boolean | "path/to/erts"
    include_src: nil, # boolean
    include_system_libs: nil, # boolean | "path/to/libs"
    strip_debug_info: nil, # boolean
    plugins: [], # list of module names
    overlay_vars: [], # keyword list
    overlays: [], # overlay list
    overrides: nil, # override list [app: app_path]
    commands: nil, # keyword list
    pre_start_hook: nil, # path or nil
    post_start_hook: nil, # path or nil
    pre_stop_hook: nil, # path or nil
    post_stop_hook: nil, # path or nil
    pre_upgrade_hook: nil, # path or nil
    post_upgrade_hook: nil, # path or nil
    pre_start_hooks: nil, # path or nil
    post_start_hooks: nil, # path or nil
    pre_stop_hooks: nil, # path or nil
    post_stop_hooks: nil, # path or nil
    pre_upgrade_hooks: nil, # path or nil
    post_upgrade_hooks: nil # path or nil

    @type t :: %__MODULE__{
      output_dir: nil | String.t,
      vm_args: nil | String.t,
      cookie: nil | Atom.t,
      config: nil | String.t,
      sys_config: nil | String.t,
      code_paths: nil | [String.t],
      erl_opts: nil | String.t,
      dev_mode: nil | boolean,
      include_erts: nil | boolean | String.t,
      include_src: nil | boolean,
      include_system_libs: nil | boolean | String.t,
      strip_debug_info: nil | boolean,
      plugins: [module()],
      overlay_vars: nil | Keyword.t,
      overlays: Mix.Releases.Overlay.overlay,
      overrides: nil | [{atom, String.t}],
      commands: nil | [{atom, String.t}],
      pre_start_hook: nil | String.t,
      post_start_hook: nil | String.t,
      pre_stop_hook: nil | String.t,
      post_stop_hook: nil | String.t,
      pre_upgrade_hook: nil | String.t,
      post_upgrade_hook: nil | String.t,
      pre_start_hooks: nil | String.t,
      post_start_hooks: nil | String.t,
      pre_stop_hooks: nil | String.t,
      post_stop_hooks: nil | String.t,
      pre_upgrade_hooks: nil | String.t,
      post_upgrade_hooks: nil | String.t
    }
end
