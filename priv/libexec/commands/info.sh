#!/usr/bin/env bash

set -o posix

set -e

require_cookie

release_remote_ctl info "$@"
