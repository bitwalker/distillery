#!/usr/bin/env bash

## This command starts the release in the foreground, i.e.
## standard out is routed to the current terminal session.

set -e
set -m

require_cookie

[ -f "$REL_DIR/$REL_NAME.boot" ] && BOOTFILE="$REL_NAME" || BOOTFILE=start
FOREGROUNDOPTIONS="-noshell -noinput +Bd"

# Setup beam-required vars
PROGNAME="${0#*/}"
export PROGNAME

# Store passed arguments since they will be erased by `set`
ARGS="$*"

# Start the VM, executing pre and post start hooks
run_hooks pre_start

# Build an array of arguments to pass to exec later on
# Build it here because this command will be used for logging.
set -- $FOREGROUNDOPTIONS \
    -boot "$REL_DIR/$BOOTFILE" \
    -args_file "$VMARGS_PATH" \
    -mode "$CODE_LOADING_MODE" \
    ${ERL_OPTS} \
    -extra ${EXTRA_OPTS}

# Dump environment info for logging purposes
if [ ! -z "$VERBOSE" ]; then
    echo "Exec: $*" -- "${1+$ARGS}"
    echo "Root: $ROOTDIR"
fi

post_start_fg() {
    sleep 2
    run_hooks post_start
}

(post_start_fg &)
erlexec "$@" -- "${1+$ARGS}"
