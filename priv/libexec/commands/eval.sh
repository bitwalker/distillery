#!/usr/bin/env bash

## Evaluate some Erlang code against the running node

set -e

release_ctl eval "$@"
