#!/bin/bash --posix

## Reloads the running system's configuration

set -e

require_cookie
require_live_node
run_hooks pre_configure

nodetool "reload_config" "$SYS_CONFIG_PATH"
