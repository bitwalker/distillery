defmodule Distillery.Releases.Profile do
  @moduledoc """
  Represents the configuration profile for a specific environment and release.
  More generally, a release has a profile, as does an environment, and
  when determining the configuration for a release in a given environment, the
  environment profile overrides the release profile.

  ## Options

    * `:output_dir`          - The directory to place release artifacts (default: `_build/<env>/rel/<name>`)
    * `:vm_args`             - When set, defines the path to a vm.args template to use
    * `:cookie`              - The distribution cookie to use when one is not provided via alternate means
    * `:sys_config`          - When set, defines the path to a custom sys.config file to use in the release
    * `:no_dot_erlang`       - Determines whether or not to pass `:no_dot_erlang` to `:systools`
    * `:executable`          - When set, builds the release into a self-extracting tar archive.
                               This setting can either be `true`, a keyword list of options implying `true`, or `false`
      * `:transient`         - One of the options possible for `:executable`. Sets the archive to remove all extracted
                               contents once execution finishes. NOTE: Only removes the self-extracted directory.
    * `:erl_opts`            - A string containing command-line arguments to pass to `erl` when running the release.
    * `:run_erl_env`         - A string containing environment variables to set when using `run_erl`
    * `:dev_mode`            - Assembles the release in a special development mode, optimized for quick feedback loops;
                               rather than copying files to the output directory, they are symlinked, avoiding the expensive
                               copies, and allowing one to run `mix compile`, restart the release, and have the changes be picked up.
                               Disables archival of the release, and is not intended for deployment use, only development and testing.
    * `:include_erts`        - Sets the strategy for locating ERTS in a release to one of the following:
      * `true`               - Bundles the current ERTS into the release (located by asking `erl` where it lives)
      * `false`              - Skips bundling an ERTS completely, but requires that one be provided on the target system
      * `"path/to/erlang"`   - As indicated, a path to the ERTS you wish to bundle. Useful for cross-compiling.
                               This path can be found with `:code.root_dir()`
    * `:include_src`         - Boolean indicating whether to bundle source files in the release. (default: false)
    * `:config_providers`    - A list of custom configuration providers to use. See `Distillery.Releases.Config.Provider` for details.
    * `:included_configs`    - Used to set paths for additional `sys.config` files to include at runtime, e.g. `["/etc/sys.config"]`
    * `:appup_transforms`    - A list of custom appup transforms to apply when building upgrades: e.g. `[MyTransform, {MyTransform, [:foo]}]`
    * `:strip_debug_info`    - Boolean indicating whether to strip debug information from BEAM files (default: false)
    * `:plugins`             - A list of custom release plugins. See `Distillery.Releases.Plugin` for details
    * `:overlay_vars`        - A list of variables to expose to overlays and templates. Must be a Keyword list
    * `:overlays`            - A list of overlays to apply. See `Distillery.Releases.Overlays` for details.
    * `:overrides`           - A list of overrides for Distillery-provided overlay vars
    * `:commands`            - A list of custom commands to add to the release, e.g. `[migrate: "rel/scripts/migrate.sh"]`

  ## Hooks

  The following options all take a path to a directory containing the scripts which will be
  executed at the given point in the release lifecycle:

    * `:pre_configure_hooks`  - Executed _before_ the system has generated config files
    * `:post_configure_hooks` - Executed _after_ config files have been generated
    * `:pre_start_hooks`      - Executed _before_ the release is started
    * `:post_start_hooks`     - Executed _after_ the release is started
    * `:pre_stop_hooks`       - Executed _before_ the release is stopped
    * `:post_stop_hooks`      - Executed _after_ the release is stopped
    * `:pre_upgrade_hooks`    - Executed _before_ a release upgrade is installed
    * `:post_upgrade_hooks`   - Executed _after_ a release upgrade is installed

  """
  defstruct output_dir: nil,
            vm_args: nil,
            cookie: nil,
            config: nil,
            sys_config: nil,
            executable: [enabled: false, transient: false],
            erl_opts: nil,
            run_erl_env: nil,
            dev_mode: nil,
            no_dot_erlang: nil,
            include_erts: nil,
            erts_version: nil,
            include_src: nil,
            include_system_libs: nil,
            included_configs: [],
            config_providers: [],
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
          cookie: nil | atom(),
          config: nil | String.t(),
          sys_config: nil | String.t(),
          executable: nil | false | Keyword.t(),
          erl_opts: nil | String.t(),
          run_erl_env: nil | String.t(),
          dev_mode: nil | boolean,
          no_dot_erlang: nil | boolean,
          include_erts: nil | boolean | String.t(),
          erts_version: nil | String.t(),
          include_src: nil | boolean,
          include_system_libs: nil | boolean | String.t(),
          included_configs: [String.t()],
          config_providers: [module() | {module(), [term]}],
          appup_transforms: [module() | {module(), [term]}],
          strip_debug_info: nil | boolean,
          plugins: [module()],
          overlay_vars: nil | Keyword.t(),
          overlays: [Distillery.Releases.Overlays.overlay()],
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
