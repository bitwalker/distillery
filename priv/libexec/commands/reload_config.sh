#!/usr/bin/env bash

set -o posix

## Reloads the running system's configuration

set -e

require_cookie
require_live_node

nodetool "reload_config" "$SYS_CONFIG_PATH"
