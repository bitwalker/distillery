#!/usr/bin/env bash

## Execute an MFA on the running node via `:rpc`

set -e

release_remote_ctl rpc "$@"
