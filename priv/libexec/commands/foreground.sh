#!/usr/bin/env bash

set -o posix

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
set -- "$BINDIR/erlexec" $FOREGROUNDOPTIONS \
    -boot "$REL_DIR/$BOOTFILE" \
    -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
    -env ERL_LIBS "$REL_LIB_DIR" \
    -pa "$CONSOLIDATED_DIR" \
    -args_file "$VMARGS_PATH" \
    -config "$SYS_CONFIG_PATH" \
    -mode "$CODE_LOADING_MODE" \
    ${ERL_OPTS} \
    -extra ${EXTRA_OPTS}

# Dump environment info for logging purposes
if [ ! -z "$VERBOSE" ]; then
    echo "Exec: $*" -- "${1+$ARGS}"
    echo "Root: $ROOTDIR"
fi;

post_start_fg() {
    sleep 2
    run_hooks post_start
}

if [ "$OTP_VER" -ge 20 ]; then
    post_start_fg &
    exec "$@" -- "${1+$ARGS}"
else
    "$@" -- "${1+$ARGS}" &
    __bg_pid=$!
    run_hooks post_start
    wait $__bg_pid
    __exit_code=$?
    run_hooks post_stop
    exit $__exit_code
fi
