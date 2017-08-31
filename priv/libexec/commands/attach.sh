#!/usr/bin/env bash

set -o posix

# Attaches to the release console as started via `start`
# NOTE: This is not a remote console, it's the shell of the running node,
# so killing the shell will kill the node as well.

set -e

require_cookie
require_live_node

PIPE_DIR="${PIPE_DIR:-$RELEASE_MUTABLE_DIR/erl_pipes/$NAME/}"

exec "$BINDIR/to_erl" "$PIPE_DIR"
