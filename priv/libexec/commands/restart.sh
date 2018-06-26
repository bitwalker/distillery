#!/usr/bin/env bash

set -o posix

## Restart the VM without exiting the process

set -e

require_cookie
run_hooks pre_start

if ! release_remote_ctl restart; then
    exit 1
fi
