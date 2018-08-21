#!/usr/bin/env bash

## Reloads the running system's configuration

set -e

if ! erl -noshell -boot "${REL_DIR}/config" -s erlang halt >/dev/null; then
    fail "Unable to configure release!"
fi
release_remote_ctl reload_config --sysconfig="$SYS_CONFIG_PATH"
