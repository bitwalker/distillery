# Shell Script API

This is the API that is exposed to custom commands and boot hooks. This API
may change, so keep an eye out here. Changes to these functions or env vars will
be considered a breaking change, so don't worry about it changing out from underneath
you in a minor version.

## Functions

  * `fail()` - Logs an error message and exits with a non-zero status code.

  * `notice()` - Logs a warning message

  * `success()` - Logs a success message

  * `info()` - Logs an informational message

  * `require_live_node()` - Ensures the release is already running and fails
  with an appropriate error if not.

  * `get_pid()` - Gets the pid of the running node. Expects that the node has
  already been started.

  * `gen_nodename()` - Generates a new unique node name based on the `NAME`
  and `NAME_TYPE` env vars. Returns it as a string.

  * `gen_id()` - Generates a unique identifier. Returns it as a string.

  * `release_ctl()` - Executes commands locally or in a clean node. You can
  pass `help` to see a list of commands and global options, and `help <cmd>`
  to see help for a specific command.

  * `release_remote_ctl()` - Executes commands against a running node.
  Like `release_ctl` you can pass `help` to get details on commands and options it
  exports. Both functions use the same underlying script, but this one is automatically
  configured to connect to the running release so you don't have to.

  * `escript()` - Executes an escript. By default this function takes the first argument
  passed to the boot script as the escript path, use the `set` builtin to reset the arguments
  to provide your own. It uses `$1` to set the escript path, and `$@` to pass arguments to that escript.

  * `erl()` - Invokes `erl` just like you would from the command line.

  * `elixir()` - Invokes `elixir` just like you would from the command line.

  * `iex()` - Invokes `iex` just like you would from the command line.

  * `otp_vsn()` - Echoes the current OTP version

  * `erts_vsn()` - Echoes the current ERTS version

  * `erts_root()` - Echoes the current root directory of ERTS

  * `run_hooks()` - Executes the hook for one of the following phases.
  It uses `$1` as the phase name to use, e.g. `run_hooks pre_configure`.

    * `pre/post_configure`
    * `pre/post_start`
    * `pre/post_stop`
    * `pre/post_upgrade`

## Environment Variables

Most all of these should be considered read-only, but those which you can manipulate
will be marked as mutable.

  * `SCRIPT` - The path to the management script

  * `SCRIPT_DIR` - The path to the parent directory of the management script

  * `RELEASE_ROOT_DIR` - The path to the release directory

  * `REL_NAME` - The name of the release

  * `REL_VSN` - The current version of the release

  * `ERTS_VSN` - The current version of ERTS used by the release

  * `CODE_LOADING_MODE (mutable)` - The mode to use when loading the release, can be "interactive" or "embedded"

  * `REL_DIR` - The path to the current release version, i.e. `releases/<vsn>`

  * `REL_LIB_DIR` - The path to the lib directory containing beams for this release

  * `ERL_OPTS (mutable)` - The options to pass to the VM when starting (should be a string)

  * `RUNNER_LOG_DIR (mutable)` - The path to the directory which will contain logs

  * `EXTRA_OPTS (mutable)` - A string of options which will be passed via `-extra` to the VM on startup

  * `NAME (mutable)` - The name of the node when run distributed, this should be a fully-qualified
  domain name when `NAME_TYPE` is set to `-name`, and a simple name when `NAME_TYPE` is set to `-sname`

  * `NAME_TYPE (mutable)` - Should be either `-sname` or `-name`, make sure you if you
  are also setting NAME that you change it to match the type you are using.

  * `REPLACE_OS_VARS (mutable)` - If set, when vm.args is read, any instances of `${VAR}`
  will be replaced with the value of the `VAR` environment variable. if unset, this will
  not occur. It is unset by default.

  * `VMARGS_PATH (mutable)` - The path to the vm.args file to use when booting the release

  * `SYS_CONFIG_PATH (mutable)` - The path to the sys.config file to use when booting the release

  * `RELEASE_CONFIG_DIR (mutable)` The path to the directory containing vm.args and sys.config files
  to use when
  booting the release. Other configs may live here too if provided by plugins such
  as conform.

  * `PIPE_DIR (mutable)` - The path to the directory which will contain the pipes when running the release
  as a daemon

  * `COOKIE (mutable)` - The secret cookie to use in distribution mode

  * `BINDIR` - The path to the ERTS bin directory
