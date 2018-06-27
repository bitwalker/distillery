defmodule Mix.Releases.Profile do
  @moduledoc """
  Represents the configuration profile for a specific environment and release.
  More generally, a release has a profile, as does an environment, and
  when determining the configuration for a release in a given environment, the
  environment profile overrides the release profile.

  ## Options

      - `output_dir`: path to place generated release
      - `vm_args`: path of the vm.args file to use
      - `cookie`: the secret cookie to use for distributed Erlang
      - `sys_config`: path of a custom sys.config file to use
      - `code_paths`: additional code paths to make available
      - `executable`: whether this release is an executable type or not
      - `exec_opts`: a keyword list of options for executable mode
        - `transient`: whether the extracted contents of an executable will be cleaned up on shutdown
      - `erl_opts`: a string containing flags to pass to the underlying VM
      - `run_erl_env`: options to pass to `run_erl` in daemon mode
      - `dev_mode`: instead of copying files into the release, they are symlinked for performance,
                    and enabling the use of code reloading in a release
      - `include_erts`: true to include the system ERTS, false to not include ERTS at all,
                        or a path to the ERTS to include, i.e. `"/usr/local/lib/erlang"`
      - `include_src`: true to include source files in the release, false to not
      - `include_system_libs`: deprecated, automatically determined
      - `included_configs`: a list of paths to include extra `sys.config` files from,
                            e.g. `["/etc/sys.config"]`
      - `config_providers`: a list of custom config providers,
                            e.g. `[MyCustomProvider, {MyOtherProvider, [:foo]}]`
      - `appup_transforms`: a list of custom appup transforms,
                            e.g. `[MyCustomTransform, {MyOtherTransform, [:foo]}]`
      - `strip_debug_info`: true to strip debug chunks from BEAM files, false to leave them as-is
      - `plugins`: a list of plugins, e.g. `[MyPlugin, {MyOtherPlugin, [:foo]}]`
      - `overlay_vars`: a keyword list of vars to make available in overlays
      - `overlays`: a list of overlays to apply, see the Overlay module docs for more
      - `overrides`: a list of overridden overlay vars (to override internal vars)
      - `commands`: a keyword list of custom commands, e.g. `[test: "path/to/test/script"]`

  ## Hooks

  The following options all take a path to a directory containing the scripts which will be
  executed at the given point in the release lifecycle:

      - `pre_configure_hooks`: before the system has generated config files
      - `post_configure_hooks` after config files have been generated
      - `pre_start_hooks`: before the release is started
      - `post_start_hooks`: after the release is started
      - `pre_stop_hooks`: before the release is stopped
      - `post_stop_hooks`: after the release is stopped
      - `pre_upgrade_hooks`: just before a release upgrade is installed
      - `post_upgrade_hooks`: just after a release upgrade is installed

  """
  defstruct output_dir: nil,
            vm_args: nil,
            cookie: nil,
            config: nil,
            sys_config: nil,
            code_paths: nil,
            executable: false,
            exec_opts: [transient: false],
            erl_opts: nil,
            run_erl_env: nil,
            dev_mode: nil,
            include_erts: nil,
            include_src: nil,
            include_system_libs: nil,
            included_configs: [],
            config_providers: [],
            # NOTE: This is to allow applications which can't support Mix.Config
            # in their releases due to compatibility problems, to disable the Mix.Config
            # provider support, falling back to the old sys.config provider instead.
            disable_mix_config_provider: nil,
            appup_transforms: [],
            strip_debug_info: nil,
            plugins: [],
            overlay_vars: [],
            overlays: [],
            overrides: nil,
            commands: nil,
            pre_configure_hooks: nil,
            post_configure_hooks: nil,
            pre_start_hooks: nil,
            post_start_hooks: nil,
            pre_stop_hooks: nil,
            post_stop_hooks: nil,
            pre_upgrade_hooks: nil,
            post_upgrade_hooks: nil

  @type t :: %__MODULE__{
          output_dir: nil | String.t(),
          vm_args: nil | String.t(),
          cookie: nil | Atom.t(),
          config: nil | String.t(),
          sys_config: nil | String.t(),
          code_paths: nil | [String.t()],
          erl_opts: nil | String.t(),
          run_erl_env: nil | String.t(),
          dev_mode: nil | boolean,
          include_erts: nil | boolean | String.t(),
          include_src: nil | boolean,
          include_system_libs: nil | boolean | String.t(),
          included_configs: [String.t()],
          config_providers: [module() | {module(), [term]}],
          disable_mix_config_provider: boolean,
          appup_transforms: [module() | {module(), [term]}],
          strip_debug_info: nil | boolean,
          plugins: [module()],
          overlay_vars: nil | Keyword.t(),
          overlays: Mix.Releases.Overlay.overlay(),
          overrides: nil | [{atom, String.t()}],
          commands: nil | [{atom, String.t()}],
          pre_configure_hooks: nil | String.t(),
          post_configure_hooks: nil | String.t(),
          pre_start_hooks: nil | String.t(),
          post_start_hooks: nil | String.t(),
          pre_stop_hooks: nil | String.t(),
          post_stop_hooks: nil | String.t(),
          pre_upgrade_hooks: nil | String.t(),
          post_upgrade_hooks: nil | String.t()
        }
end
