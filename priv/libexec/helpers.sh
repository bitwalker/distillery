#!/usr/bin/env bash

set -e

# Ensures the current node is running, otherwise fails
require_live_node() {
    require_cookie
    if ! release_ctl ping --name="$NAME" --cookie="$COOKIE" >/dev/null; then
        fail "Node $NAME is not running!"
    else
        return 0
    fi
}

# Get node pid
get_pid() {
    if output="$(release_remote_ctl rpc 'List.to_string(:os.getpid())')"
    then
        echo "$output" | sed -e 's/"//g'
        return 0
    else
        echo "$output"
        return 1
    fi
}

# Generate a unique nodename
gen_nodename() {
    id="$(gen_id)"
    node="$(echo "${NAME}" | cut -d'@' -f1)"
    host="$(echo "${NAME}" | cut -d'@' -f2 -s)"
    if [ -z "$host" ] && [ "$NAME_TYPE" = "-name" ]; then
        # No hostname specified, and we're using long names, so use HOSTNAME
        echo "${node}-${id}@${HOSTNAME}"
    elif [ -z "$host" ]; then
        # No hostname specified, but we're using -sname
        echo "${node}-${id}"
    elif [ "$NAME_TYPE" = "-sname" ]; then
        # Hostname specified, but we're using -sname
        echo "${node}-${id}"
    else
        # Hostname specified, and we're using long names
        echo "${node}-${id}@${host}"
    fi
}

# Print the current hostname
get_hostname() {
    host="$(echo "${NAME}" | cut -d'@' -f2 -s)"
    if [ -z "$host" ]; then
        echo "${HOSTNAME}"
    else
        echo "$host"
    fi
}

# Generate a random id
gen_id() {
    od -t x -N 4 /dev/urandom | head -n1 | awk '{print $2}'
}

## Run hooks for one of the configured startup phases
run_hooks() {
    case $1 in
        pre_configure)
            _run_hooks_from_dir "$PRE_CONFIGURE_HOOKS"
            ;;
        post_configure)
            _run_hooks_from_dir "$POST_CONFIGURE_HOOKS"
            ;;
        pre_start)
            _run_hooks_from_dir "$PRE_START_HOOKS"
            ;;
        pre_stop)
            _run_hooks_from_dir "$PRE_STOP_HOOKS"
            ;;
        post_start)
            _run_hooks_from_dir "$POST_START_HOOKS"
            ;;
        post_stop)
            _run_hooks_from_dir "$POST_STOP_HOOKS"
            ;;
        pre_upgrade)
            _run_hooks_from_dir "$PRE_UPGRADE_HOOKS"
            ;;
        post_upgrade)
            _run_hooks_from_dir "$POST_UPGRADE_HOOKS"
            ;;
    esac
}

# Private. Run hooks from directory.
_run_hooks_from_dir() {
    if [ -d "$1" ]; then
        for file in $1/[0-9a-zA-Z._-]*; do
            [ -f "$file" ] || continue
            . "$file"
        done
    fi
}
