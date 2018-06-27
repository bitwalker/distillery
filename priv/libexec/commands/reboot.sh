#!/usr/bin/env bash

set -o posix

## Restart the VM completely

set -e

require_cookie
run_hooks pre_start

if ! release_remote_ctl reboot; then
    exit 1
fi

# Node needs to be brought back up without heart
if ! release_ctl ping --peer="$NAME" --cookie="$COOKIE" >/dev/null; then
    exec "$RELEASE_ROOT_DIR/bin/$REL_NAME" start
fi
