#!/usr/bin/env bash

## DEPRECATED: Just use `ping --name=<name>` or
## `ping --name=<name> --cookie=<cookie>`
##
## This command is like `ping`, but pings an arbitrary peer

set -e

require_cookie

case $1 in
    --*)
        # New format, --cookie will be overridden if passed
        if ! release_ctl ping --cookie="$COOKIE" "$@"; then
            exit 1
        fi
        ;;
    *)
        # Old format
        if ! release_ctl ping --cookie="$COOKIE" --name="$1"; then
            exit 1
        fi
        ;;
esac
