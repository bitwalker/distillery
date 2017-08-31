#!/usr/bin/env bash --posix

## Execute an MFA on the running node via `:rpc`

set -e

require_cookie
require_live_node

nodetool rpc "$@"
