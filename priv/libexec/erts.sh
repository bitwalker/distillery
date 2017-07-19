#!/bin/bash --posix

set -e

# Echoes the path to the current ERTS binaries, e.g. erl
whereis_erts_bin() {
    if [ -z "$ERTS_VSN" ]; then
        set +e
        __erts_bin="$(dirname "$(which erl)")"
        set -e
        echo "$__erts_bin"
    else
        __erts_dir="$RELEASE_ROOT_DIR/erts-$ERTS_VSN"
        if [ -d "$__erts_dir" ]; then
            echo "$__erts_dir/bin"
        else
            unset ERTS_VSN
            whereis_erts_bin
        fi
    fi
}

# Invokes erl with the provided arguments
erl() {
    __erl="$(whereis_erts_bin)/erl"
    if [ -z "$__erl" ]; then
        fail "Erlang runtime not found. If Erlang is installed, ensure it is in your PATH"
    else
        "$__erl" "$@"
    fi
}

# Echoes the current ERTS version
erts_vsn() {
    erl -eval 'Ver = erlang:system_info(version), io:format("~s~n", [Ver]), halt()' -noshell -boot start_clean
}

# Echoes the current ERTS root directory
erts_root() {
    erl -eval 'io:format("~s~n", [code:root_dir()]), halt().' -noshell -boot start_clean
}

# Echoes the current OTP version
otp_vsn() {
    erl -eval 'Ver = erlang:system_info(otp_release), io:format("~s~n", [Ver]), halt()' -noshell -boot start_clean
}

# Control a node
# Use like `nodetool "ping"`
nodetool() {
    command="$1"; shift
    name="${PEERNAME:-$NAME}"
    __escript="$(whereis_erts_bin)/escript"
    "$__escript" "$ROOTDIR/bin/nodetool" "$NAME_TYPE" "$name" \
                 -setcookie "$COOKIE" "$command" "$@"
}

# Run an escript in the node's environment
# Use like `escript "path/to/escript"`
escript() {
    scriptpath="$1"; shift
    export RELEASE_ROOT_DIR
    __escript="$(whereis_erts_bin)/escript"
    "$__escript" "$ROOTDIR/$scriptpath" "$@"
}

export ROOTDIR
ROOTDIR="$(erts_root)"
export ERTS_VSN
if [ -z "$ERTS_VSN" ]; then
    # Update start_erl.data
    ERTS_VSN="$(erts_vsn)"
    echo "$ERTS_VSN $REL_VSN" > "$START_ERL_DATA"
fi
ERTS_VSN="$(erts_vsn)"
export ERTS_DIR
ERTS_DIR="$ROOTDIR/erts-$ERTS_VSN"
export BINDIR
BINDIR="$ERTS_DIR/bin"
export ERTS_LIB_DIR
ERTS_LIB_DIR="$ERTS_DIR/../lib"
export EMU="beam"
export PROGNAME="erl"
