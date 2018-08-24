#!/usr/bin/env bash

## This command unpacks a specific version of a release.
## This does NOT install the version.

set -e

if [ ! -z "$RELEASE_READ_ONLY" ]; then
    fail "Cannot unpack a release with RELEASE_READ_ONLY set!"
fi

release_remote_ctl unpack \
        --release="$REL_NAME" \
        "$2"
