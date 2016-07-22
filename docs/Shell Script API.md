# Shell Script API

This is the API that is exposed to custom commands and boot hooks. This API
may change, so keep an eye out here. Changes to these functions or env vars will
be considered a breaking change, so don't worry about it changing out from underneath
you in a minor version.

## Functions

### get_pid()

Gets the pid of the running node. Expects that the node has already been started.

### gen_nodename()

Generates a new unique node name based on the `NAME` and `NAME_TYPE` env vars. Returns
it as a string.

### gen_id()

Generates a unique identifier. Returns it as a string.

### nodetool()

Executes the node tool against a running node. It uses the arguments passed to the
boot script, but you can use the `set` builtin to change what those arguments are.
It uses `$1` to set the command for the nodetool, and `$@` to pass arguments to that
command.

### escript()

Executes an escript. By default this function takes the first argument passed to the boot
script as the escript path, use the `set` builtin to reset the arguments to provide your
own. It uses `$1` to set the escript path, and `$@` to pass arguments to that escript.

## Environment Variables

Most all of these should be considered read-only, but those which you can manipulate
will be marked as mutable.

```
- SCRIPT;
  the path to the boot script
- SCRIPT_DIR;
  the path to the parent directory of the boot script
- RELEASE_ROOT_DIR;
  the path to the release directory
- REL_NAME;
  the name of the release
- REL_VSN;
  the current version of the release
- ERTS_VSN;
  the current version of ERTS used by the release
- CODE_LOADING_MODE (mutable);
  the mode to use when loading the release, can be "interactive" or "embedded"
- REL_DIR;
  the path to the current release version, i.e. releases/<vsn>/
- REL_LIB_DIR;
  the path to the lib directory containing beams for this release
- ERL_OPTS (mutable);
  the options to pass to the VM when starting (should be a string)
- RUNNER_LOG_DIR (mutable);
  the path to the directory which will contain logs
- EXTRA_OPTS (mutable);
  a string of options which will be passed via `-extra` to the VM on startup
- NAME (mutable);
  the name of the node when run distributed, this should be a fully-qualified
  domain name when NAME_TYPE is set to `-name`, and a simple name when NAME_TYPE
  is set to `-sname`
- NAME_TYPE (mutable);
  should be either `-sname` or `-name`, make sure you if you are also setting NAME
  that you change it to match the type you are using.
- REPLACE_OS_VARS (mutable);
  if set, when vm.args is read, any instances of `${VAR}` will be replaced with the
  value of the `VAR` environment variable. if unset, this will not occur. It is unset
  by default.
- VMARGS_PATH (mutable);
  the path to the vm.args file to use when booting the release
- SYS_CONFIG_PATH (mutable);
  the path to the sys.config file to use when booting the release
- RELEASE_CONFIG_DIR (mutable);
  the path to the directory containing vm.args and sys.config files to use when
  booting the release. Other configs may live here too if provided by plugins such
  as conform.
- PIPE_DIR (mutable);
  the path to the directory which will contain the pipes when running the release
  as a daemon
- COOKIE (mutable);
  the secret cookie to use in distribution mode
- BINDIR;
  the path to the ERTS bin directory
```
