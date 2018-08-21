#!/usr/bin/env bash

## Print a summary of information about this release

set -e

_load_cookie

release_ctl describe \
            --release-root-dir="$RELEASE_ROOT_DIR" \
            --release="$REL_NAME" \
            --name="$NAME" \
            --cookie="$COOKIE" \
            --sysconfig="$SYS_CONFIG_PATH" \
            --vmargs="$VMARGS_PATH" \
            --erl-opts="$ERL_OPTS" \
            --run-erl-env="$RUN_ERL_ENV"
