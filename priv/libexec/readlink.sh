#!/usr/bin/env bash

set -e

if [ ! -z "$DEBUG_BOOT" ]; then
    # Disable debug mode in this file
    set +x
fi

# If readlink has no -f option, or greadlink is not available,
# This function behaves like `readlink -f`
__readlink_f() {
    __target_file="$1"
    cd "$(dirname "$__target_file")"
    __target_file=$(basename "$__target_file")

    # Iterate down a (possible) chain of symlinks
    while [ -L "$__target_file" ]
    do
        __target_file=$(readlink "$__target_file")
        cd "$(dirname "$__target_file")"
        __target_file=$(basename "$__target_file")
    done
    # Compute the canonicalized name by finding the physical path
    # for the directory we're in and appending the target file.
    __phys_dir=$(pwd -P)
    __result="$__phys_dir/$__target_file"
    echo "$__result"
}

readlink_f() {
    # Locate the real path to this script
    if uname | grep -q 'Darwin'; then
        # on OSX, best to install coreutils from homebrew or similar
        # to get greadlink
        if command -v greadlink >/dev/null 2>&1; then
            greadlink -f "$1"
        else
            __readlink_f "$1"
        fi
    else
        readlink -f "$1"
    fi
}

if [ ! -z "$DEBUG_BOOT" ]; then
    # Re-enable it after
    set -x
fi
