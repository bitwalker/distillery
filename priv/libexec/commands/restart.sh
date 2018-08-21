#!/usr/bin/env bash

## Restart the VM without exiting the process

set -e

if ! release_remote_ctl restart; then
    exit 1
fi
