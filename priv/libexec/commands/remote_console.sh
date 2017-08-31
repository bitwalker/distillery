#!/usr/bin/env bash

set -o posix

## Connect a remote shell to a running node

set -e

require_cookie
require_live_node

# Generate a unique id used to allow multiple remsh to the same node
# transparently
id="remsh$(gen_id)-${NAME}"

# Get the node's ticktime so that we use the same thing.
TICKTIME="$(nodetool rpcterms net_kernel get_net_ticktime)"

# Setup remote shell command to control node
if [ ! -z "$USE_ERL_SHELL" ]; then
    exec "$BINDIR/erl" \
        -hidden \
        -boot start_clean -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
        -kernel net_ticktime "$TICKTIME" \
        "$NAME_TYPE" "$id" -remsh "$NAME" -setcookie "$COOKIE"
else
    __code_paths=$(_get_code_paths)
    exec "$BINDIR/erl" \
        -pa "$CONSOLIDATED_DIR" \
        ${__code_paths} \
        -hidden -noshell \
        -boot start_clean -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
        -kernel net_ticktime "$TICKTIME" \
        -user Elixir.IEx.CLI "$NAME_TYPE" "$id" -setcookie "$COOKIE" \
        -extra --no-halt +iex -"$NAME_TYPE" "$id" --cookie "$COOKIE" --remsh "$NAME"
fi
