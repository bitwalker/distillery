#!/usr/bin/env bash

set -o posix

## Evaluate some Erlang code against the running node

set -e

release_ctl eval "$@"
