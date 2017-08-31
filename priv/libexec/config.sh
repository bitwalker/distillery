#!/usr/bin/env bash

set -o posix

set -e

# Sets config paths for sys.config and vm.args, and ensures that env var replacements are performed
configure_release() {
    # If a preconfigure hook calls back to the boot script, do not
    # try to init the configs again, as it will result in an infinite loop
    if [ ! -z "$DISTILLERY_PRECONFIGURE" ]; then
        return 0
    fi

    # Need to ensure pre_configure is run here, but
    # prevent recursion if the hook calls back to the boot script
    export DISTILLERY_PRECONFIGURE=true
    run_hooks pre_configure
    unset DISTILLERY_PRECONFIGURE

    # Set VMARGS_PATH, the path to the vm.args file to use
    # Use $RELEASE_CONFIG_DIR/vm.args if exists, otherwise releases/VSN/vm.args
    if [ -z "$VMARGS_PATH" ]; then
        if [ -f "$RELEASE_CONFIG_DIR/vm.args" ]; then
            export SRC_VMARGS_PATH="$RELEASE_CONFIG_DIR/vm.args"
        else
            export SRC_VMARGS_PATH="$REL_DIR/vm.args"
        fi
    else
        export SRC_VMARGS_PATH="$VMARGS_PATH"
    fi
    if [ "$SRC_VMARGS_PATH" != "$RELEASE_MUTABLE_DIR/vm.args" ]; then
        echo "#### Generated - edit/create $RELEASE_CONFIG_DIR/vm.args instead." \
            >  "$RELEASE_MUTABLE_DIR/vm.args"
        cat  "$SRC_VMARGS_PATH"                              \
            >> "$RELEASE_MUTABLE_DIR/vm.args"
        export DEST_VMARGS_PATH="$RELEASE_MUTABLE_DIR"/vm.args
    fi
    if [ ! -z "$REPLACE_OS_VARS" ]; then
        _replace_os_vars "$DEST_VMARGS_PATH"
    fi
    export VMARGS_PATH="${VMARGS_PATH:-$DEST_VMARGS_PATH}"

    # Set SYS_CONFIG_PATH, the path to the sys.config file to use
    # Use $RELEASE_CONFIG_DIR/sys.config if exists, otherwise releases/VSN/sys.config
    if [ -z "$SYS_CONFIG_PATH" ]; then
        if [ -f "$RELEASE_CONFIG_DIR/sys.config" ]; then
            export SRC_SYS_CONFIG_PATH="$RELEASE_CONFIG_DIR/sys.config"
        else
            export SRC_SYS_CONFIG_PATH="$REL_DIR/sys.config"
        fi
    else
        export SRC_SYS_CONFIG_PATH="$SYS_CONFIG_PATH"
    fi
    if [ "$SRC_SYS_CONFIG_PATH" != "$RELEASE_MUTABLE_DIR/sys.config" ]; then
        (echo "%% Generated - edit/create $RELEASE_CONFIG_DIR/sys.config instead."; \
        cat  "$SRC_SYS_CONFIG_PATH")                              \
            > "$RELEASE_MUTABLE_DIR/sys.config"
        export DEST_SYS_CONFIG_PATH="$RELEASE_MUTABLE_DIR"/sys.config
    fi
    if [ ! -z "$REPLACE_OS_VARS" ]; then
        _replace_os_vars "$DEST_SYS_CONFIG_PATH"
    fi
    export SYS_CONFIG_PATH="${SYS_CONFIG_PATH:-$DEST_SYS_CONFIG_PATH}"

    # Need to ensure post_configure is run here, but
    # prevent recursion if the hook calls back to the boot script
    export DISTILLERY_PRECONFIGURE=true
    run_hooks post_configure
    unset DISTILLERY_PRECONFIGURE

    # Set up the node based on the new configuration
    _configure_node

    return 0
}

# Do a textual replacement of ${VAR} occurrences in $1 and pipe to $2
_replace_os_vars() {
    awk '
        function escape(s) {
            gsub(/'\&'/, "\\\\&", s);
            return s;
        }
        {
            while(match($0,"[$]{[^}]*}")) {
                var=substr($0,RSTART+2,RLENGTH-3);
                gsub("[$]{"var"}", escape(ENVIRON[var]))
            }
        }1' < "$1" > "$1.bak"
    mv -- "$1.bak" "$1"
}


# Sets up the node name configuration for clustering/remote commands
_configure_node() {
    # Extract the target node name from node.args
    # Should be `-sname somename` or `-name somename@somehost`
    export NAME_ARG
    NAME_ARG="$(grep -E '^-s?name' "$VMARGS_PATH" || true)"
    if [ -z "$NAME_ARG" ]; then
        echo "vm.args needs to have either -name or -sname parameter."
        exit 1
    fi

    # Extract the name type and name from the NAME_ARG for REMSH
    # NAME_TYPE should be -name or -sname
    export NAME_TYPE
    NAME_TYPE="$(echo "$NAME_ARG" | awk '{print $1}' | tail -n 1)"
    # NAME will be either `somename` or `somename@somehost`
    export NAME
    NAME="$(echo "$NAME_ARG" | awk '{print $2}' | tail -n 1)"

    # User can specify an sname without @hostname
    # This will fail when creating remote shell
    # So here we check for @ and add @hostname if missing
    case $NAME in
        *@*)
            # Nothing to do
            ;;
        *)
            NAME=$NAME@$(gen_nodename)
            ;;
    esac
}

# Ensure that cookie is set.
require_cookie() {
    # Attempt reloading cookie in case it has been set in a hook
    if [ -z "$COOKIE" ]; then
        _load_cookie
    fi
    # Die if cookie is still not set, as connecting via distribution will fail
    if [ -z "$COOKIE" ]; then
        fail "a secret cookie must be provided in one of the following ways:\n  - with vm.args using the -setcookie parameter,\n  or\n  by writing the cookie to '$DEFAULT_COOKIE_FILE', with permissions set to 0400"
        exit 1
    fi
}

# Load target cookie, either from vm.args or $HOME/.cookie
_load_cookie() {
    COOKIE_ARG="$(grep '^-setcookie' "$VMARGS_PATH" || true)"
    DEFAULT_COOKIE_FILE="$HOME/.erlang.cookie"
    if [ -z "$COOKIE_ARG" ]; then
        if [ -f "$DEFAULT_COOKIE_FILE" ]; then
            COOKIE="$(cat "$DEFAULT_COOKIE_FILE")"
        fi
    else
        # Extract cookie name from COOKIE_ARG
        COOKIE="$(echo "$COOKIE_ARG" | awk '{print $2}')"
    fi
}
