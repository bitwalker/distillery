#!/usr/bin/env bash

## Start a daemon in the background with an attachable shell

set -e

if [ ! -z "$RELEASE_READ_ONLY" ]; then
    fail "Cannot start a release with RELEASE_READ_ONLY set!"
fi

require_cookie

# Output a start command for the last argument of run_erl
_start_command() {
    printf "exec \"%s\" \"%s\" -- %s %s" "$RELEASE_ROOT_DIR/bin/$REL_NAME" \
           "$START_OPTION" "${ARGS}" "${EXTRA_OPTS}"
}

CMD=$1
case "$1" in
    start)
        shift
        START_OPTION="console"
        HEART_OPTION="start"
        ;;
    start_boot)
        shift
        START_OPTION="console_boot"
        HEART_OPTION="start_boot"
        ;;
esac
ARGS="$*"
RUN_PARAM="$*"

run_hooks pre_start

# Set arguments for the heart command
set -- "$SCRIPT_DIR/$REL_NAME" "$HEART_OPTION"
[ "$RUN_PARAM" ] && set -- "$@" "$RUN_PARAM"

# Export the HEART_COMMAND
HEART_COMMAND="$RELEASE_ROOT_DIR/bin/$REL_NAME $CMD"
export HEART_COMMAND

PIPE_DIR="${PIPE_DIR:-$RELEASE_MUTABLE_DIR/erl_pipes/$NAME/}"
mkdir -p "$PIPE_DIR"

env $RUN_ERL_ENV "$BINDIR/run_erl" -daemon "$PIPE_DIR" "$RUNNER_LOG_DIR" \
    "$(_start_command)"

run_hooks post_start
