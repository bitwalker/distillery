#!/usr/bin/env bash

set -o posix

## This command is used to execute an escript using the release ERTS

set -e

require_cookie

if ! escript "$@"; then
    exit 1
fi
