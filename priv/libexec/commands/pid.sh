#!/usr/bin/env bash

set -o posix

## Print the running node's process id to stdout

set -e

require_cookie

if ! get_pid; then
    exit 1
fi
