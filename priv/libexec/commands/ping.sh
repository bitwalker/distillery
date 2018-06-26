#!/usr/bin/env bash

set -o posix

## Pings the running node, or an arbitrary peer node
## by supplying `--peer` and `--cookie` flags.
##
## If the node is running and can be connected to,
## 'pong' will be printed to stdout. If the node is
## not reachable or cannot be connected to due to an
## invalid cookie, 'pang' will be printed to stdout
## and the command will exit with a non-zero status code.

set -e

require_cookie

if ! release_ctl ping --peer="$NAME" --cookie="$COOKIE" "$@"; then
    exit 1
fi
