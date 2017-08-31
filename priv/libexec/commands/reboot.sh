#!/usr/bin/env bash

set -o posix

## Restart the VM completely (uses heart to restart it)

set -e

require_cookie
run_hooks pre_start

if ! nodetool "reboot"; then
    exit 1
fi
