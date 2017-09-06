#!/usr/bin/env bash

set -o posix

set -e

# Ensures the current node is running, otherwise fails
require_live_node() {
    if ! nodetool "ping" >/dev/null; then
        fail "Node $NAME is not running!"
    else
        return 0
    fi
}

# Get node pid
get_pid() {
    if output="$(nodetool rpcterms os getpid)"
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
    id="longname$(gen_id)-${NAME}"
    "$BINDIR/erl" -boot start_clean -eval '[Host] = tl(string:tokens(atom_to_list(node()),"@")), io:format("~s~n", [Host]), halt()' -noshell "${NAME_TYPE}" "$id"
}

# Generate a random id
gen_id() {
    od -t x -N 4 /dev/urandom | head -n1 | awk '{print $2}'
}

## Run hooks for one of the configured startup phases
run_hooks() {
    _old_erl_libs="${ERL_LIBS:-}"
    export ERL_LIBS="$ERTS_LIB_DIR:$REL_LIB_DIR:$CONSOLIDATED_DIR"
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
    ERL_LIBS="$_old_erl_libs"
}

# Private. Run hooks from directory.
_run_hooks_from_dir() {
    if [ -d "$1" ]; then
        for file in $1/[0-9a-zA-Z]*.sh; do
            [ -f "$file" ] || continue
            . "$file"
        done
    fi
}

# Private. Gets a list of code paths for this release
_get_code_paths() {
    escript "bin/release_utils.escript" "get_code_paths" "$ROOTDIR" "$ERTS_DIR" "$REL_NAME" "$REL_VSN"
}
