## 0.10.0

## Added

- 565bea5 - Erlang distribution cookie made configurable - Thomas Stratmann

## Changed

- You can now override the start type of applications by using
  `set applications: [app: start_type]` in `rel/config.exs`. Previously,
  this would only work if the application was not present in the applications
  list of `mix.exs`
- If you provide a custom `sys.config` with `set sys_config: path`, it will now
  be merged over the top of the one that would be generated from `config.exs`, so
  that you can override settings per-environment.

## Fixed

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
