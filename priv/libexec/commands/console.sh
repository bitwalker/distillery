#!/usr/bin/env bash

## This command starts the release interactively, i.e. it boots to a shell

set -e

require_cookie

# .boot file typically just $REL_NAME (ie, the app name)
# however, for debugging, sometimes start_clean.boot is useful.
# For e.g. 'setup', one may even want to name another boot script.
command="$1"
case "$1" in
    console)
        shift
        if [ -f "$REL_DIR/$REL_NAME.boot" ]; then
            BOOTFILE="$REL_DIR/$REL_NAME"
        else
            BOOTFILE="$REL_DIR/start"
        fi
        ;;
    console_clean)
        shift
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

# Start the VM, executing pre_start hook along
# the way. We can't run the post_start hook because
# the console will crash with no TTY attached
run_hooks pre_start

# Dump environment info for logging purposes
if [ ! -z "$VERBOSE" ]; then
    echo "Exec: $command" -- "$*" "${EXTRA_OPTS}"
    echo "Root: $ROOTDIR"
    echo "Boot: $BOOTFILE"
    echo "Args: $VMARGS_PATH"
    echo "Mode: $CODE_LOADING_MODE"
    echo "Opts: ${ERL_OPTS}"

    # Log the startup
    echo "$RELEASE_ROOT_DIR"
fi

logger -t "$REL_NAME[$$]" "Starting up"

erlexec \
    -boot "$BOOTFILE" \
    -args_file "$VMARGS_PATH" \
    -mode "$CODE_LOADING_MODE" \
    ${ERL_OPTS} \
    -user Elixir.IEx.CLI \
    -extra --no-halt +iex \
    -- "$@"
