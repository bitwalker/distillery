#!/usr/bin/env bash

set -o posix

## Print a summary of information about this release

set -e

_load_cookie

release_ctl describe \
            --release_root_dir="$RELEASE_ROOT_DIR" \
            --release="$REL_NAME" \
            --name="$NAME" \
            --cookie="$COOKIE" \
            --sysconfig="$SYS_CONFIG_PATH" \
            --vmargs="$VMARGS_PATH" \
            --config="$CONFIG_EXS_PATH" \
            --erl_opts="$ERL_OPTS" \
            --run_erl_env="$RUN_ERL_ENV"
