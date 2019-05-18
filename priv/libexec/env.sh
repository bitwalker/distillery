#!/usr/bin/env bash

set -e

# Disable flow control for run_erl
# Flow control can cause several problems. On Linux, if you
# accidentally hit Ctrl-S (instead of Ctrl-D to detach) and
# then some other key, the entire beam process will hang when
# attempting to write to stdout. On Solaris, the beam process
# will hang on writing if ScrollLock is on.
RUN_ERL_DISABLE_FLOWCNTRL="${RUN_ERL_DISABLE_FLOWCNTRL:-true}"
# VM code loading mode, embedded by default, can also be interactive
# See http://erlang.org/doc/man/code.html
CODE_LOADING_MODE="${CODE_LOADING_MODE:-embedded}"
# The lib directory for this release
REL_LIB_DIR="${REL_LIB_DIR:-$RELEASE_ROOT_DIR/lib}"
# The location of generated files and other mutable state
RELEASE_MUTABLE_DIR="${RELEASE_MUTABLE_DIR:-$RELEASE_ROOT_DIR/var}"
# When stdout is piped to a file, this is the directory those files will
# be stored in. defaults to /log in the release root directory
RUNNER_LOG_DIR="${RUNNER_LOG_DIR:-$RELEASE_MUTABLE_DIR/log}"
# A string of extra options to pass to erl, here for plugins
EXTRA_OPTS="${EXTRA_OPTS:-}"
# The hook paths for each of the available hookable events
reset_hooks() {
    export PRE_CONFIGURE_HOOKS="$REL_DIR/hooks/pre_configure.d"
    export POST_CONFIGURE_HOOKS="$REL_DIR/hooks/post_configure.d"
    export PRE_START_HOOKS="$REL_DIR/hooks/pre_start.d"
    export POST_START_HOOKS="$REL_DIR/hooks/post_start.d"
    export PRE_STOP_HOOKS="$REL_DIR/hooks/pre_stop.d"
    export POST_STOP_HOOKS="$REL_DIR/hooks/post_stop.d"
    export PRE_UPGRADE_HOOKS="$REL_DIR/hooks/pre_upgrade.d"
    export POST_UPGRADE_HOOKS="$REL_DIR/hooks/post_upgrade.d"
}
reset_hooks

# Exported environment variables
export BINDIR="$ERTS_DIR/bin"
export LD_LIBRARY_PATH="$ERTS_DIR/lib:$LD_LIBRARY_PATH"
export EMU="beam"
export PROGNAME="erl"

# Allow override of where to read configuration from
# By default it's RELEASE_ROOT_DIR
export RELEASE_CONFIG_DIR="${RELEASE_CONFIG_DIR:-$RELEASE_ROOT_DIR}"

# Make sure important directories exist
if [ -z "$RELEASE_READ_ONLY" ] && [ ! -d "$RELEASE_MUTABLE_DIR" ]; then
    mkdir -p "$RELEASE_MUTABLE_DIR"
    echo "Files in this directory are regenerated frequently, edits will be lost" \
        > "$RELEASE_MUTABLE_DIR/WARNING_README"
fi

if [ -z "$RELEASE_READ_ONLY" ] && [ ! -d "$RUNNER_LOG_DIR" ]; then
    mkdir -p "$RUNNER_LOG_DIR"
fi
