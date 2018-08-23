#!/usr/bin/env bash

## Connect a remote shell to a running node

set -e

require_cookie
require_live_node

# Generate a unique id used to allow multiple remsh to the same node
# transparently
id="remsh$(gen_id)-${NAME}"

# Get the node's ticktime so that we use the same thing.
TICKTIME="$(release_remote_ctl rpc ':net_kernel.get_net_ticktime()')"

# Setup remote shell command to control node
if [ ! -z "$USE_ERL_SHELL" ]; then
    erl -hidden \
        -kernel logger_level warning \
        -kernel net_ticktime "$TICKTIME" \
        "$NAME_TYPE" "$id" \
        -remsh "$NAME" \
        -setcookie "$COOKIE"
else
    iex --erl "-hidden -kernel net_ticktime $TICKTIME" \
        --logger-sasl-reports false \
        -"$NAME_TYPE" "$id" \
        --cookie "$COOKIE" \
        --remsh "$NAME"
fi
