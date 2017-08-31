#!/usr/bin/env bash

set -o posix

# Like `rpc`, but parses the third argument as an Erlang term

set -e

require_cookie
require_live_node

nodetool rpcterms "$@"
