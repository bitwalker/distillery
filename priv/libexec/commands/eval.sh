#!/bin/bash --posix

## Evaluate some Erlang code against the running node

set -e

require_cookie
require_live_node

nodetool "eval" "$@"
