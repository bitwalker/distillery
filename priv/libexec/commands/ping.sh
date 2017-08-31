#!/usr/bin/env bash

set -o posix

## This command sends a "ping" to the running node.
## If the node is not running, or cannot be reached,
## an error will be printed. If the node is running,
## but cannot be connected to, "pang" is printed.

set -e

require_cookie

if ! nodetool "ping"; then
    exit 1
fi
