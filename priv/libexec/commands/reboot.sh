#!/usr/bin/env bash

## Restart the VM completely

set -e

require_cookie

if ! release_remote_ctl reboot; then
    exit 1
fi

sleep 1

# Check to see if node is back, if not, restart it without heart
# Node needs to be brought back up without heart
if ! release_remote_ctl ping >/dev/null; then
    . "$REL_DIR/libexec/commands/start.sh" start
fi
