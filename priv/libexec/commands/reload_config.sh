#!/usr/bin/env bash

set -o posix

## Reloads the running system's configuration

set -e

require_cookie
require_live_node

release_remote_ctl reload_config \
                   --sysconfig="$SYS_CONFIG_PATH"
