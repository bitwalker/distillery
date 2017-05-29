## 1.5

### Added

- Introduced new configuration option `included_configs`, which is a list of paths pointing to additional config files to be merged into `sys.config` at runtime.


## 1.4

### Changed

- `command` now automatically stops after command finishes executing
- `pre_configure` hook now runs prior to `command`
- Improved signal handling to return correct exit status codes


### Fixed

- Handling of `run_erl_env` is fixed
- Various potential bugs reported by shellcheck in boot scripts
- Compilation was broken on 1.3, it is now fixed

## 1.3

### Added

- Preliminary Windows support, feedback is welcome!

### Changed

- Only write `start_erl.data` when detecting ERTS

### Fixed

- #212 - missing profile option for release task
- #214 - run post_stop hooks after foreground exit

## 1.2.2

### Fixed

- Handling of configs during upgrades (#139)

## 1.2.1

### Fixed

- Handling of ERTS detection in boot script

## 1.2.0

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

## 1.1.2

### Fixed

- Handling of removed applications during hot upgrades

## 1.1.1

### Changed

- Ignore deps not used at runtime (#189) (Saša Jurić)
- Default environment in generated config is `Mix.env`
- Warn about mismatched ERTS when `include_erts: false`

### Fixed

- Reduce chance of invalid sys.config during boot (#188) (Hugh Watkins)
- Expose some additional boot script variables so plugins can access them

## 1.1.0

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

## 1.0.0

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

## 0.10.0

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

## 0.9.3

### Fixed

- Fixed start types not being honored when resolving apps
- Fixed dependencies missing from applications list not
  being added to the release. They are now added with a
  start type of :load.
- Fixed src directory being added to release when include_src is false
- Fixed hidden files in apps directory of umbrellas causing an exception
