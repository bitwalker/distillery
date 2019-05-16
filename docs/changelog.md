# Changelog

All notable changes to this project will be documented in this file (at least to the extent possible, I am not infallible sadly).

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html)

## [2.1.0] - Unreleased

### Breaking Changes

- In order to be compatible with Elixir 1.9, Mix tasks have been renamed:
    - `mix distillery.release`
    - `mix distillery.release.clean`
    - `mix distillery.init`
    - `mix distillery.gen.appup`
- Additionally, all public APIs that used the `Mix.Releases` namespace are now
  under the `Distillery.Releases` namespace, notably this affects plugin modules,
  config providers, and `rel/config.exs` config files.

## [2.0.3]

### Added

- Added `--mfa` flag to `rpc` and `eval` commands, which specifies a module/function/arity
  string to apply, using arguments provided to the command. Arguments are not transformed in
  any way, but applied as string values. You can also pass `--argv` with `--mfa` to change the
  behavior such that all arguments are passed as a single list of arguments, much like you'd get
  in a Mix task; using `--argv` implies an arity of 1, so if you pass an mfa string with a different
  arity, an error will be returned.

## [2.0.0]

This is a major release with a number of significant changes and some of which are breaking,
please read these notes carefully! There are a great many improvements and bug
fixes. Unfortunately the bug fixes are so numerous that I can't list them all
here, but if you are interested, the git history is clean, and should
provide a good overview of what has been addressed.

### Added

- The `Mix.Releases.Config.Provider` behavior and API. Referred to as
  "Config Providers" in more general terms, this provides a format and source
  agnostic way to configure your application at runtime. Providers are executed
  prior to boot/init, in an environment with all application code loaded, with
  only `kernel`, `stdlib`, `compiler`, and `elixir` applications started.
  They are executed in the order listed in
  your config, and should push their configuration into the application
  environment (e.g. via `Application.put_env/3`). It is expected that when
  running multiple providers, the last one to run "wins" in the case of
  conflicting configuration keys, so they should be ordered by their priority.
- A `Mix.Config` config provider, supporting `config.exs` scripts in releases.
  You can find more information in the `Mix.Releases.Config.Providers.Elixir`
  module docs, or in the Distillery documentation about config providers.
- A new `config_providers` setting for defining which config providers to
  execute in a release (can be set in either `environment` or `release` blocks).
- Support for writing a PID file to disk (useful for running under systemd in
  particular). It is enabled with `-kernel pidfile '"path/to/pidfile"'` or by
  exporting `PIDFILE` in the environment. When enabled, the file is written to
  disk and then checked every 5s - if the file is deleted, the node is
  terminated as soon as the next check is performed. This process is executed as
  a kernel process, and so should survive `:init.restart/0`.
- Provide `release.gen.appup` task, for generating `.appup` files for a given
  application and version. This can be used to generate appups under `rel` for
  safe keeping, and easy modification. See `mix help release.gen.appup` for more
  details, it is a huge improvement if you are using hot upgrades!
- Provide "read-only" mode for management scripts, which do not write any files
  when `RELEASE_READ_ONLY` is exported in the environment. This is intended to
  be used for executing commands as a user other than the one used to start the
  release via `foreground`, `start`, or `console`,
- Raise a friendlier error when the ERTS specified was compiled for another OS when
  booting the release
- Provide appup transforms - a plugin system for modifying appups
  programmatically during release builds.


### Fixed

- A lot of bugs, too many to list here

### Changed

- **BREAKING:** Distillery now requires Elixir 1.6+ and OTP 20+ - if you are on
  older versions, you may be able to use Distillery, but it is not guaranteed to
  compile - if it does, it should work. Distillery is upping the compat
  requirements in order to stay lean for integration with the core tooling.
- **BREAKING:** The `rpc` command now takes an Elixir expression as a string, and evals it on the remote node
- **BREAKING:** The `eval` command now takes an Elixir expression as a string, and evals it locally in a clean node
- The `release_utils` and `nodetool` scripts have been rewritten in Elixir
- The `include_system_libs` option is deprecated, as it is automatically determined based on other settings
- The `include_src` option now includes `lib` directory (i.e. Elixir code)
- The `:silent` verbosity level is now completely silent except for errors
- The `:quiet` verbosity level now only shows warnings/errors
- SASL logs are disabled by default, with level set to `:error`. SASL is still
  required. In OTP 21, you may still see SASL reports if the kernel `logger`
  module is configured with a `info` level - SASL no longer has it's own logger,
  these now go through the new logger module, so there is no longer a
  distinction made for these reports.
- Significant internal refactoring and clean up to move to a more modular,
  maintainable structure.
- **IMPORTANT:** Distillery is now bundled into releases, as Elixir code for the
  command-line tooling and config providers are part of Distillery, and needs to be available on the
  code path. This means that you should remove `runtime: false` from the
  Distillery dependency - to ease the transition, Distillery will ignore this
  flag when set on itself, and bundle into the release anyway, but you should
  remove it to prevent confusion.
- Support `:no_dot_erlang` option for systools
- Performance optimizations for applications with many dependencies
- Don't guess application names in umbrella projects

### Deprecations

- **BREAKING:** The `rpcterms` command has been removed as it is no longer necessary
- **BREAKING:** All of the `<event>_hook` config options have been removed in favor of `<event>_hooks`, for example
  `pre_start_hook` is a path to a single script for the `pre_start` hook, you would now place that script
  in a new directory, perhaps `rel/pre_start_hooks`, and change the config to point to that directory rather
  than the script. This allows you to define multiple hooks for a given event. This config has been in place
  for a long time now, but this release finally removes the old options
- The `exec_opts` option for setting executable options has been deprecated in
  favor of just `executable`, which now expects a Keyword list of `[enabled:
  boolean, transient: boolean]`, you can use `executable: true` to imply
  `enabled: true`, `transient` still defaults to false.

## [1.5] - 2017-08-15

**IMPORTANT**: Distillery now requires that Bash be installed on the target system.
It turns out that this had been an implied dependency due to some of the features used
in the old script, but since it used `/bin/sh` in its shebang, most platforms used Bash
automatically anyway. Those platforms which alias `/bin/sh` to something not Bash, such as
Ubuntu, were broken in some ways. This dependency on a specific shell's behaviour is now
explicit rather than implicit.

### Added

- Introduced new configuration option `included_configs`, which is a list of paths pointing to additional config files to be merged into `sys.config` at runtime.
- Support for Elixir 1.5
- Added `elixir` and `iex` helper functions for custom commands and hooks

### Changed

- The boot script architecture has been completely re-written
  - Support for OTP 20's new signal handler
  - Boot script is now broken up into smaller components for easier maintenance
  - Each command lives in its own script now, using the same basic infra as custom commands
  - Improved documentation
- `pre_configure` is now run prior to any config initialization to provide an opportunity to set up the environment.

### Fixed

- Various documentation improvements
- Fix handling of dumb terminals (#298)
- Fix handling of consolidation path (#307)


## [1.4] - 2017-05-10

### Changed

- `command` now automatically stops after command finishes executing
- `pre_configure` hook now runs prior to `command`
- Improved signal handling to return correct exit status codes


### Fixed

- Handling of `run_erl_env` is fixed
- Various potential bugs reported by shellcheck in boot scripts
- Compilation was broken on 1.3, it is now fixed

## [1.3] - 2017-03-24

### Added

- Preliminary Windows support, feedback is welcome!

### Changed

- Only write `start_erl.data` when detecting ERTS

### Fixed

- #212 - missing profile option for release task
- #214 - run post_stop hooks after foreground exit

## [1.2.2] - 2017-02-27

### Fixed

- Handling of configs during upgrades (#139)

## [1.2.1] - 2017-02-27

### Fixed

- Handling of ERTS detection in boot script

## [1.2.0] - 2017-02-27

### Added

- Add the ability to generate "executables (self-extracting archives),
  which can be used to build releases which can be used as command-line utilities.
  See `mix help release` for more info.
- Implement `reload_config` command for runtime reconfiguration
- Implement `pre_configure` hook which is now used prior to any time the configuration
 will be evaluated to ensure tools like conform are able to do their work first. This
 is being used in order to facilitate `reload_config`, and potentially other commands like
 it in the future.
- Implement simple API for the Release object for use by other libraries.

### Changed

- All errors are now handled via a single Errors module to unify error handling throughout
  the project. This should result in better errors everywhere
- Print more readabile usage information from boot script
- Parse options strictly to prevent unintended mistakes from going unnoticed

### Fixed

- Do a better job of detecting valid release versions
- Certain environment config options are ignored (#204)
- Fix win32 executable exit conditions (#202) - Matt Enlow
- Ensure code_change/4 is detected for special processes

## [1.1.2] - 2017-02-11

### Fixed

- Handling of removed applications during hot upgrades

## [1.1.1] - 2017-02-09

### Changed

- Ignore deps not used at runtime (#189) (Saša Jurić)
- Default environment in generated config is `Mix.env`
- Warn about mismatched ERTS when `include_erts: false`

### Fixed

- Reduce chance of invalid sys.config during boot (#188) (Hugh Watkins)
- Expose some additional boot script variables so plugins can access them

## [1.1.0] - 2017-01-11

### Added

- `describe` command for the boot script (Paul Schoenfelder)
- Export DISTILLERY_TASK for hooks/commands (Martin Langhoff)
- Add `pingpeer` command

### Changed

- Implement default behaviours for plugin callbacks (Justin Schneck)
- Automatically import plugins from `rel/plugins` (Paul Schoenfelder)
- Make plugin options optional when using `set plugins`
- Various documentation fixes, additions, etc.

### Fixed

- #165 - Ensure trapped signals wait for node to completely shut down before exiting (Paul Schoenfelder)
- #134 - Dependency order issues can cause kernel/stdlib to be undefined

## [1.0.0] - 2016-12-05

*NOTE*: This release contains breaking changes!

### Added

- Link to config helpers package - Andrew Dryga
- ea3c791 - Allow passing a custom eex template to use for the init task - Justin Schneck
- Add pre/post upgrade hooks - @spscream
- Allow passing options to plugins - Michal Muskala

### Changed

- Default output path for release artifacts is `_build/<env>/rel/<relname>`,
  this can be configured in `rel/config.exs` with `set output_dir: "path"`
- Allow variables to be used with environment/release macros in config
- Unpack release prior to executing pre-upgrade scripts

### Fixed

- 675f492 - Fix issue with terminal color output not being reset (#126) - Akira Takahashi
- 9c7fc9f - Accept --name option as documented for release.init - Victor Borja
- 851a622 - Fix typo in pre_stop hook overlay - Alexander Malaev
- d5da953 - Make execution of hooks to work on busybox - Alexander Malaev
- 75e80bf - Add support for hooks directories - Alexander Malaev
- <multiple> - Fix detection of ERTS_VSN in boot script - Mario Sangiorgio/Paul Schoenfelder
- 5a420e6 - Fix issue with loading of code paths - Paul Schoenfelder
- d6bec3a - Fix update instruction for supervisor in appups - Andrew Shu
- a837cb8 - Fix handling of nil name in release.init for umbrella projects - dmytro@pharosproduction.com
- 1db006f - Fix archiver when passing path in include_system_libs - Justin Schneck
- <multiple> - Fix generating cookies with reserved characters - Paul Schoenfelder
- 2f4c064 - Fix varname typo breaking code_paths - Martin Langhoff
- 67d9d49 - Various code path fixes - Martin Langhoff
- 16e2159 - Invalid folders in apps dir should be ignored - Paul Schoenfelder
- 6bebdb6 - Properly handle symlinks when copying apps - Paul Schoenfelder
- 8beae24 - Fix missing option in clean task - Paul Schoenfelder

## [0.10.0] - 2016-10-02

### Added

- 565bea5 - Erlang distribution cookie made configurable - Thomas Stratmann

### Changed

- You can now override the start type of applications by using
  `set applications: [app: start_type]` in `rel/config.exs`. Previously,
  this would only work if the application was not present in the applications
  list of `mix.exs`
- If you provide a custom `sys.config` with `set sys_config: path`, it will now
  be merged over the top of the one that would be generated from `config.exs`, so
  that you can override settings per-environment.

### Fixed

- 45f7c16 - make sure `$__erl` is not empty. Fixes #70
- f0304a8 - Document and handle the case of not including ERTS when using hot upgrades - Paul Schoenfelder (HEAD -> master)
- f2517ab - Fix detection of pre-existing appups to check that it's for the current upgrade - Paul Schoenfelder
- 8dacbc8 - Merge install_upgrade.escript and release_utils.escript. Fix handling of get_code_paths to use RELEASES - Paul Schoenfelder
- a0e3bdc - boot: guard VMARGS_PATH and SYSCONFIG_PATH from recursive calls - Martin Langhoff
- 1360cc3 - Fix some issues with the path handling in the command task - Paul Schoenfelder
- 90a09ee - Add code paths to erl when running command task. See #67 - Paul Schoenfelder
- 42de09e - Refactor cookie check to occur during config application - Paul Schoenfelder
- 4718976 - Fix formatting of cookie warning - Paul Schoenfelder
- 9ceefaf - boot: re-establish RELEASE_MUTABLE_DIRECTORY, with cleaner semantics - Martin Langhoff
- f3c053d - boot: Improve release directory resolution - Martin Langhoff
- cdfd563 - Fix all Elixir 1.4 warnings - Andrea Leopardi
- b008b73 - tasks/release: ensure :distillery is loaded - Martin Langhoff
- bd835ea - Fix logger tests - Paul Schoenfelder
- 5ed8a74 - Fix unescaped ampersands when calling awk for REPLACE_OS_VARS=true. See bitwalker/exrm#390 - Paul Schoenfelder
- 0058ec9 - Strip ANSI color codes in non-TTY mode - Paul Schoenfelder
- 57dc0af - make bash script unset CDPATH to avoid no such file or directory errors - Mike Stok
- 1933ec2 - you can't use '-' in an application name - hykw
- 016a184 - (docs) Missing a `do` in mix command - Kyle Oba
- e01cacb - (docs) Adds Phoenix walkthrough and Use document - supernullset

## [0.9.3] - 2016-08-17

### Fixed

- Fixed start types not being honored when resolving apps
- Fixed dependencies missing from applications list not
  being added to the release. They are now added with a
  start type of :load.
- Fixed src directory being added to release when include_src is false
- Fixed hidden files in apps directory of umbrellas causing an exception
