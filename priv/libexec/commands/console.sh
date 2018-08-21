#!/usr/bin/env bash

## This command starts the release interactively, i.e. it boots to a shell

set -e

require_cookie

# .boot file typically just $REL_NAME (ie, the app name)
# however, for debugging, sometimes start_clean.boot is useful.
# For e.g. 'setup', one may even want to name another boot script.
case "$1" in
    console)
        if [ -f "$REL_DIR/$REL_NAME.boot" ]; then
            BOOTFILE="$REL_DIR/$REL_NAME"
        else
            BOOTFILE="$REL_DIR/start"
        fi
        ;;
    console_clean)
        BOOTFILE="$RELEASE_ROOT_DIR/bin/start_clean"
        ;;
    console_boot)
        shift
        BOOTFILE="$1"
        shift
        ;;
esac

# Setup beam-required vars
PROGNAME="${0#*/}"
export PROGNAME

# Store passed arguments since they will be erased by `set`
ARGS="$*"

# Start the VM, executing pre_start hook along
# the way. We can't run the post_start hook because
# the console will crash with no TTY attached
run_hooks pre_start

# Build an array of arguments to pass to exec later on
# Build it here because this command will be used for logging.
set -- \
    -boot "$BOOTFILE" \
    -args_file "$VMARGS_PATH" \
    -mode "$CODE_LOADING_MODE" \
    ${ERL_OPTS} \
    -user Elixir.IEx.CLI \
    -extra --no-halt +iex

# Dump environment info for logging purposes
if [ ! -z "$VERBOSE" ]; then
    echo "Exec: $*" -- "${1+$ARGS}" "${EXTRA_OPTS}"
    echo "Root: $ROOTDIR"

    # Log the startup
    echo "$RELEASE_ROOT_DIR"
fi

logger -t "$REL_NAME[$$]" "Starting up"

erlexec "$@" -- "${1+$ARGS}" "${EXTRA_OPTS}"
