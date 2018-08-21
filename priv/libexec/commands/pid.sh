#!/usr/bin/env bash

## Print the running node's process id to stdout

set -e

if ! get_pid; then
    exit 1
fi
