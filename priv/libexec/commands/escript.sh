#!/usr/bin/env bash

## This command is used to execute an escript using the release ERTS

set -e

if ! escript "$@"; then
    exit 1
fi
