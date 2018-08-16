#!/usr/bin/env bash

set -o posix

## Reloads the running system's configuration

set -e

require_cookie
require_live_node

if ! erl -noshell -boot "${REL_DIR}/config" -kernel logger_level warning -s erlang halt; then
    fail "Unable to configure release!"
fi
release_remote_ctl reload_config --sysconfig="$SYS_CONFIG_PATH"
