#!/usr/bin/env bash

## This command is used to install upgrades/downgrades.
## It takes two arguments, the type of install (i.e. upgrade/downgrade),
## and the version to install.

set -e

if [ -z "$2" ]; then
    fail "Missing package argument\\nUsage: $REL_NAME $1 <version>"
fi

if [ ! -z "$RELEASE_READ_ONLY" ]; then
    fail "Cannot install a release upgrade with RELEASE_READ_ONLY set!"
fi

require_live_node

SOURCE_VERSION="$REL_VSN"
TARGET_VERSION="$2"

release_remote_ctl unpack \
         --release="$REL_NAME" \
         "$TARGET_VERSION"

# Update environment to reflect target version environment
export REL_VSN="$TARGET_VERSION"
export REL_DIR="$RELEASE_ROOT_DIR/releases/$TARGET_VERSION"

# Prepare new configs
if [ "$SRC_VMARGS_PATH" = "$RELEASE_MUTABLE_DIR/vm.args" ]; then
    unset VMARGS_PATH
else
    if [ "$SRC_VMARGS_PATH" = "$RELEASE_ROOT_DIR/releases/$SOURCE_VERSION/vm.args" ]; then
        unset VMARGS_PATH
    else
        export VMARGS_PATH="$SRC_VMARGS_PATH"
    fi
fi
if [ "$SRC_SYS_CONFIG_PATH" = "$RELEASE_MUTABLE_DIR/sys.config" ]; then
    unset SYS_CONFIG_PATH
else
    if [ "$SRC_SYS_CONFIG_PATH" = "$RELEASE_ROOT_DIR/releases/$SOURCE_VERSION/sys.config" ]; then
        unset SYS_CONFIG_PATH
    else
        export SYS_CONFIG_PATH="$SRC_SYS_CONFIG_PATH"
    fi
fi
configure_release
# We have to do some juggling to ensure the correct config is used by the upgrade handler
# First, we detect if there was a failed upgrade, so we can start over
if [ -f "$REL_DIR/sys.config.bak" ]; then
    mv "$REL_DIR/sys.config.bak" "$REL_DIR/sys.config"
fi
if [ -f "$REL_DIR/vm.args.bak" ]; then
    mv "$REL_DIR/vm.args.bak" "$REL_DIR/vm.args"
fi
# Then, backup the packaged configs
cp -a "$REL_DIR/sys.config" "$REL_DIR/sys.config.bak"
cp -a "$REL_DIR/vm.args" "$REL_DIR/vm.args.bak"
# Then, substitute in the prepared configs
cp -a "$SYS_CONFIG_PATH" "$REL_DIR/sys.config"
cp -a "$VMARGS_PATH" "$REL_DIR/vm.args"

# Run any pre-upgrade tasks
run_hooks pre_upgrade

release_remote_ctl install \
         --release="$REL_NAME" \
         "$TARGET_VERSION"

# We were successful, clean up the configs
mv "$REL_DIR/sys.config.bak" "$REL_DIR/sys.config"
mv "$REL_DIR/vm.args.bak" "$REL_DIR/vm.args"

# Update environment
reset_code_paths
reset_hooks

# Run any post-upgrade hooks
run_hooks post_upgrade
