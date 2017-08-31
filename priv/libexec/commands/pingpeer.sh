#!/usr/bin/env bash

set -o posix

## This command is like `ping`, but is used to
## ping a neighboring node. It requires a single
## argument which is the name of the peer to ping.

set -e

PEERNAME=$1 nodetool "ping"
exit_status=$?
if [ "$exit_status" -ne 0 ]; then
    exit $exit_status
fi
