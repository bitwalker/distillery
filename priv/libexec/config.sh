#!/usr/bin/env bash

set -e

# Determines the path to the current vm.args file to use
get_vmargs_path() {
    if [ -z "$VMARGS_PATH" ]; then
        if [ -f "$RELEASE_MUTABLE_DIR/vm.args" ]; then
            echo "$RELEASE_MUTABLE_DIR/vm.args"
        fi
        if [ -f "$RELEASE_CONFIG_DIR/vm.args" ]; then
            echo "$RELEASE_CONFIG_DIR/vm.args"
        fi
    else
        echo "$VMARGS_PATH"
    fi

    echo ""
}

# We're expecting that the real configs have been generated at
# least once already, otherwise we don't set any env vars here
# so as to prevent loading invalid configs/arg files
#
# See 'configure_release' for more info
partial_configure_release() {
    if [ -z "$VMARGS_PATH" ]; then
        if [ -f "$RELEASE_MUTABLE_DIR/vm.args" ]; then
            export VMARGS_PATH="$RELEASE_MUTABLE_DIR/vm.args"
        elif [ -f "$RELEASE_CONFIG_DIR/vm.args" ]; then
            export VMARGS_PATH="$RELEASE_CONFIG_DIR/vm.args"
        fi
    fi

    if [ -z "$SYS_CONFIG_PATH" ]; then
        if [ -f "$RELEASE_MUTABLE_DIR/sys.config" ]; then
            export SYS_CONFIG_PATH="$RELEASE_MUTABLE_DIR/sys.config"
        elif [ -f "$RELEASE_CONFIG_DIR/sys.config" ]; then
            export SYS_CONFIG_PATH="$RELEASE_CONFIG_DIR/sys.config"
        fi
    fi

    if [ -z "$VMARGS_PATH" ] || [ -z "$SYS_CONFIG_PATH" ]; then
        # We need to generate the config files for the first time
        configure_release
    else
        # Set up the node based on the new configuration
        _configure_node
    fi
}

# Sets config paths for sys.config and vm.args, and ensures that env var replacements are performed
configure_release() {
    # If a preconfigure hook calls back to the run control script, do not
    # try to init the configs again, as it will result in an infinite loop
    if [ ! -z "$DISTILLERY_PRECONFIGURE" ]; then
        return 0
    fi

    # Need to ensure pre_configure is run here, but
    # prevent recursion if the hook calls back to the run control script
    export DISTILLERY_PRECONFIGURE=true
    run_hooks pre_configure
    unset DISTILLERY_PRECONFIGURE

    ## NOTE: Please read the following to understand what is going on here:
    # This code hides a great deal of implicit behavior, so it is important to
    # understand as much of the whole picture as possible.
    #
    # 1. Source config files must remain immutable, this is to ensure that when
    #    we replace environment variables in them, that these replacements do not
    #    become effectively permanent.
    # 2. We must not generate files when RELEASE_READ_ONLY is set
    # 3. We must respect the public shell script API, which includes SYS_CONFIG_PATH,
    #    and VMARGS_PATH. This means that if provided, we must use
    #    them as the source file, but we must update them to point to the m
    # 4. The upgrade installer script unpacks new config files, but attempts to use
    #    the sources defined here, rather than those included in the release. This is
    #    so that configuration is not blown away when the upgrade is applied, instead
    #    the new config file can be applied as needed. This of course could fail if a
    #    required config change is in the new files, but that is a change management issue,
    #    not one that we can solve in this script.
    #
    # For some additional discussion on the motivations behind this code, please review
    # https://github.com/bitwalker/issues/398 - the code under discussion there is already
    # out of date, but the conversation is still relevant now.

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
        if [ -z "$RELEASE_READ_ONLY" ]; then
            echo "#### Generated - edit/create $RELEASE_CONFIG_DIR/vm.args instead." \
                >  "$RELEASE_MUTABLE_DIR/vm.args"
            cat  "$SRC_VMARGS_PATH" \
                >> "$RELEASE_MUTABLE_DIR/vm.args"
            export DEST_VMARGS_PATH="$RELEASE_MUTABLE_DIR/vm.args"
        else
            export DEST_VMARGS_PATH="$SRC_VMARGS_PATH"
        fi
    fi
    if [ -z "$RELEASE_READ_ONLY" ] && [ ! -z "$REPLACE_OS_VARS" ]; then
        if [ ! -z "$DEST_VMARGS_PATH" ]; then
            _replace_os_vars "$DEST_VMARGS_PATH"
        fi
    fi
    export VMARGS_PATH="${DEST_VMARGS_PATH:-$VMARGS_PATH}"

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
        if [ -z "$RELEASE_READ_ONLY" ]; then
            echo "%% Generated - edit/create $RELEASE_CONFIG_DIR/sys.config instead." \
                > "$RELEASE_MUTABLE_DIR/sys.config"
            cat  "$SRC_SYS_CONFIG_PATH" \
                >> "$RELEASE_MUTABLE_DIR/sys.config"
            export DEST_SYS_CONFIG_PATH="$RELEASE_MUTABLE_DIR/sys.config"
        else
            export DEST_SYS_CONFIG_PATH="$SRC_SYS_CONFIG_PATH"
        fi
    fi
    if [ -z "$RELEASE_READ_ONLY" ] && [ ! -z "$REPLACE_OS_VARS" ]; then
        if [ ! -z "$DEST_SYS_CONFIG_PATH" ]; then
            _replace_os_vars "$DEST_SYS_CONFIG_PATH"
        fi
    fi
    export SYS_CONFIG_PATH="${DEST_SYS_CONFIG_PATH:-$SYS_CONFIG_PATH}"

    if [ -z "$RELEASE_READ_ONLY" ]; then
        # Now that we have a full base config, run the config providers pass
        # This will replace the config at SYS_CONFIG_PATH with a fully provisioned config
        # Set the logger level to warning to prevent unnecessary output to stdio
        if [ -z "$DEBUG_BOOT" ]; then
            # Silence all output when not debugging, but print errors
            set +e
            err="$(erl -noshell -config "$SYS_CONFIG_PATH" -boot "${REL_DIR}/config" -s erlang halt)"
            status=$?
            set -e
            if [ $status -ne 0 ]; then
                echo "$err"
                fail "Unable to configure release!"
            fi
        else
            # Otherwise, show any output produced
            if ! erl -noshell -config "$SYS_CONFIG_PATH" -boot "${REL_DIR}/config" -s erlang halt; then
                fail "Unable to configure release!"
            fi
        fi
    fi

    # Need to ensure post_configure is run here, but
    # prevent recursion if the hook calls back to the run control script
    export DISTILLERY_PRECONFIGURE=true
    run_hooks post_configure
    unset DISTILLERY_PRECONFIGURE

    # Set up the node based on the new configuration
    _configure_node

    return 0
}

# Do a textual replacement of ${VAR} occurrences in $1 and pipe to $2
_replace_os_vars() {
    # Copy the source file to preserve permissions
    cp -a "$1" "$1.bak"
    # Perform the replacement, rewriting $1.bak
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
    # Replace $1 with the rewritten $1.bak
    mv -- "$1.bak" "$1"
}

# Do a textual replacement of ${VAR} occurrances in $1 and pipe to stdout
_replace_os_vars_str() {
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
    }1' < "$1"
}

# Sets up the node name configuration for clustering/remote commands
_configure_node() {
    # Already configured
    if [ ! -z "$NAME" ]; then
        if [ ! -z "$NAME_TYPE" ]; then
            return 0
        else
            export NAME_TYPE
            case $NAME in
                *@*)
                    NAME_TYPE="-name"
                    ;;
                *)
                    HOSTNAME="$(get_hostname)"
                    if [[ ! "$HOSTNAME" =~ ^[^\.]+\..*$ ]]; then
                        # If the hostname is not fully qualified, change the name type
                        NAME_TYPE="-sname"
                    else
                        NAME_TYPE="-name"
                    fi
                    NAME="$NAME@$HOSTNAME"
                    ;;
            esac
            return 0
        fi
    fi

    # We need to detect configuration from vm.args
    vmargs="$(get_vmargs_path)"
    if [ -z "$vmargs" ]; then
        fail "Unable to load vm.args and NAME is not exported, unable to configure node!"
    fi

    # Extract the target node name from node.args
    # Should be `-sname somename` or `-name somename@somehost`
    export NAME_ARG
    NAME_ARG="$(_replace_os_vars_str "${vmargs}" | grep '^-s\{0,1\}name' || true)"
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
    if [ -z "$NAME" ]; then
        fail "Invalid $NAME_TYPE value in vm.args, value is empty!"
    fi

    # User can specify an sname without @hostname
    # This will fail when creating remote shell
    # So here we check for @ and add @hostname if missing
    case $NAME in
        *@*)
            if [[ "$NAME" =~ ^[^@]+@[^\.]+\..*$ ]]; then
                if [ "$NAME_TYPE" = "-sname" ]; then
                    fail "cannot use fully-qualified name '$NAME' with -sname argument!"
                fi
            fi
            ;;
        *)
            if [ "$NAME_TYPE" != "-sname" ]; then
                HOSTNAME="$(get_hostname)"
                OLD_NAME="$NAME"
                NAME="$NAME@$HOSTNAME"
                NAME_TYPE="-name"
                notice "Automatically converted short name ($OLD_NAME) to long name ($NAME)!"
                notice "It is recommended that you set a fully-qualified name in vm.args instead"
            fi
            ;;
    esac
}

# Ensure that cookie is set.
require_cookie() {
    # Load cookie, if not already loaded
    _load_cookie
    # Die if cookie is still not set, as connecting via distribution will fail
    if [ -z "$COOKIE" ]; then
        fail "a secret cookie must be provided in one of the following ways:\n  - with vm.args using the -setcookie parameter,\n  or\n  by writing the cookie to '$DEFAULT_COOKIE_FILE', with permissions set to 0400"
        exit 1
    fi
}

# Load target cookie, either from vm.args or $HOME/.cookie
_load_cookie() {
    if [ ! -z "$COOKIE" ]; then
        return 0
    fi
    vmargs="$(get_vmargs_path)"
    if [ -z "$vmargs" ]; then
        return 1
    fi
    COOKIE_ARG="$(_replace_os_vars_str "${vmargs}" | grep '^-setcookie' || true)"
    DEFAULT_COOKIE_FILE="$HOME/.erlang.cookie"
    if [ ! -z "$COOKIE_ARG" ]; then
        COOKIE="$(echo "$COOKIE_ARG" | awk '{ print $2 }')"
    elif [ -f "$DEFAULT_COOKIE_FILE" ]; then
        COOKIE="$(cat "$DEFAULT_COOKIE_FILE")"
    elif [ -z "$RELEASE_READ_ONLY" ]; then
        # Try generating one by starting the VM
        if erl -noshell -name "$NAME" -s erlang halt >/dev/null; then
            if [ -f "$DEFAULT_COOKIE_FILE" ]; then
                COOKIE="$(cat "$DEFAULT_COOKIE_FILE")"
                return 0
            fi
        fi
        return 1
    else
        return 1
    fi
}
