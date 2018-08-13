#!/usr/bin/env bash

set -o posix
set -e

__rel_apps() {
    __releases="$RELEASE_ROOT_DIR/releases/RELEASES"
    __vsn="$(echo "$REL_VSN" | sed -e 's/+/\\\+/')"
    __rel="$(cat "$__releases" | sed -E -n "/\{release,[^,]*,\"$__vsn\"/,/[^po]*(permanent|old)/p")"
    echo "$__rel" \
        | grep -E '[{][A-Za-z_0-9]*,\"[0-9.]*[A-Za-z0-9.\_\+\-]*\"' \
        | tail -n +2 \
        | sed -e's/"[^"]*$//' \
              -e's/^[^a-z]*//' \
              -e's/,/-/' \
              -e's/"//' \
              -e's/","[^"]*$//'
}

code_paths=()
__set_code_paths() {
    if [ ${#code_paths[@]} -eq 0 ]; then
        code_paths=()
        apps="$(__rel_apps)"
        for app in $apps; do
            if [ -d "${ERTS_LIB_DIR}/$app" ]; then
                code_paths+=(-pa "${ERTS_LIB_DIR}/$app/ebin")
            elif [ -d "${RELEASE_ROOT_DIR}/lib/$app" ]; then
                code_paths+=(-pa "${RELEASE_ROOT_DIR}/lib/$app/ebin")
            elif [ -L "${RELEASE_ROOT_DIR}/lib/$app" ]; then
                code_paths+=(-pa "${RELEASE_ROOT_DIR}/lib/$app/ebin")
            else
                fail "Could not locate code path for $app!"
            fi
        done
    fi
}

# Echoes the path to the current ERTS binaries, e.g. erl
whereis_erts_bin() {
    if [ -z "$ERTS_VSN" ]; then
        set +e
        __erts_bin="$(dirname "$(type -P erl)")"
        set -e
        echo "$__erts_bin"
    elif [ -z "$USE_HOST_ERTS" ]; then
        __erts_dir="$RELEASE_ROOT_DIR/erts-$ERTS_VSN"
        if [ -d "$__erts_dir" ]; then
            echo "$__erts_dir/bin"
        else
            ERTS_VSN=
            whereis_erts_bin
        fi
    else
        ERTS_VSN=
        whereis_erts_bin
    fi
}

# Invokes erl with the provided arguments
erl() {
    __erl="$(whereis_erts_bin)/erl"
    if [ -z "$__erl" ]; then
        fail "Erlang runtime not found. If Erlang is installed, ensure it is in your PATH"
    fi
    # If EXTRA_CODE_PATHS is given, add -pa flag for the paths
    __extra_paths=""
    if [ ! -z "$EXTRA_CODE_PATHS" ]; then
        __extra_paths="-pa ${EXTRA_CODE_PATHS}"
    fi
    # If SYS_CONFIG_PATH is set, add the -config flag to erl
    __sysconfig=""
    if [ ! -z "$SYS_CONFIG_PATH" ]; then
        __sysconfig="-config ${SYS_CONFIG_PATH}"
    fi
    # Set flag for whether a boot script was provided by the caller
    __boot_provided=0
    if echo "$@" | grep '\-boot ' >/dev/null; then
        __boot_provided=1
    fi
    # Set flag for whether the current erl is from a bundled ERTS
    __erts_included=0
    if [[ "$__erl" =~ ^$RELEASE_ROOT_DIR ]]; then
        __erts_included=1
    fi
    if [ $__erts_included -eq 1 ] && [ $__boot_provided -eq 1 ]; then
        # Bundled ERTS with -boot set
        "$__erl" -boot_var ERTS_LIB_DIR "$RELEASE_ROOT_DIR/lib" \
                 ${__sysconfig} \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${__extra_paths} \
                 "$@"
    elif [ $__erts_included -eq 1 ]; then
        # Bundled ERTS, using default boot script 'start_none'
        "$__erl" -boot_var ERTS_LIB_DIR "$RELEASE_ROOT_DIR/lib" \
                 -boot "$RELEASE_ROOT_DIR/bin/start_none" \
                 ${__sysconfig} \
                 ${__extra_paths} \
                 "$@"
    elif [ $__boot_provided -eq 0 ]; then
        # Host ERTS with -boot not set
        "$__erl" -boot start_clean \
                 ${__sysconfig} \
                 "${code_paths[@]}" \
                 -pa "${RELEASE_ROOT_DIR}"/lib/*/ebin \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${__extra_paths} \
                 "$@"
    elif [ -z "$ERTS_LIB_DIR" ]; then
        # Host ERTS, -boot set, no ERTS_LIB_DIR available
        "$__erl" \
                 ${__sysconfig} \
                 "${code_paths[@]}" \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${__extra_paths} \
                 "$@"
    else
        # Host ERTS, -boot set, ERTS_LIB_DIR available
        "$__erl" -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
                 ${__sysconfig} \
                 "${code_paths[@]}" \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${__extra_paths} \
                 "$@"
    fi
}

erlexec(){
    __erl="$(whereis_erts_bin)/erl"
    __extra_paths=""
    # If EXTRA_CODE_PATHS is set, add -pa flag for the paths
    if [ ! -z "$EXTRA_CODE_PATHS" ]; then
        __extra_paths="-pa ${EXTRA_CODE_PATHS}"
    fi
    # If SYS_CONFIG_PATH is set, add -config flag to erl
    __sysconfig=""
    if [ ! -z "$SYS_CONFIG_PATH" ]; then
        __sysconfig="-config ${SYS_CONFIG_PATH}"
    fi
    if [ -z "$__erl" ]; then
        fail "Erlang runtime not found. If Erlang is installed, ensure it is in your PATH"
    fi
    if [[ "$__erl" =~ ^$RELEASE_ROOT_DIR ]]; then
        # Bundled ERTS
        exec "$BINDIR/erlexec" -boot_var ERTS_LIB_DIR "$RELEASE_ROOT_DIR/lib" \
                               ${__sysconfig} \
                               -pa "${CONSOLIDATED_DIR}" \
                               ${__extra_paths} \
                               "$@"
    else
        # Host ERTS
        exec "$BINDIR/erlexec" -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
                               ${__sysconfig} \
                               -pa "${RELEASE_ROOT_DIR}"/lib/*/ebin \
                               -pa "${CONSOLIDATED_DIR}" \
                               ${__extra_paths} \
                               "$@"
    fi
}

# Run Elixir
elixir() {
    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      echo "Usage: `basename $0` [options] [.exs file] [data]

      -e COMMAND                  Evaluates the given command (*)
      -r FILE                     Requires the given files/patterns (*)
      -S SCRIPT                   Finds and executes the given script in PATH
      -pr FILE                    Requires the given files/patterns in parallel (*)
      -pa PATH                    Prepends the given path to Erlang code path (*)
      -pz PATH                    Appends the given path to Erlang code path (*)

      --app APP                   Starts the given app and its dependencies (*)
      --cookie COOKIE             Sets a cookie for this distributed node
      --detached                  Starts the Erlang VM detached from console
      --erl SWITCHES              Switches to be passed down to Erlang (*)
      --help, -h                  Prints this message and exits
      --hidden                    Makes a hidden node
      --logger-otp-reports BOOL   Enables or disables OTP reporting
      --logger-sasl-reports BOOL  Enables or disables SASL reporting
      --name NAME                 Makes and assigns a name to the distributed node
      --no-halt                   Does not halt the Erlang VM after execution
      --sname NAME                Makes and assigns a short name to the distributed node
      --version, -v               Prints Elixir version and exits
      --werl                      Uses Erlang's Windows shell GUI (Windows only)

    ** Options marked with (*) can be given more than once
    ** Options given after the .exs file or -- are passed down to the executed code
    ** Options can be passed to the Erlang runtime using ELIXIR_ERL_OPTIONS or --erl" >&2
      exit 1
    fi
    MODE="elixir"
    ERL=""
    I=1
    while [ $I -le $# ]; do
        S=1
        eval "PEEK=\${$I}"
        case "$PEEK" in
            +iex)
                MODE="iex"
                ;;
            +elixirc)
                MODE="elixirc"
                ;;
            -v|--compile|--no-halt)
                ;;
            -e|-r|-pr|-pa|-pz|--remsh|--app)
                S=2
                ;;
            --detatched|--hidden)
                ERL="$ERL `echo $PEEK | cut -c 2-`"
                ;;
            --cookie)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                ERL="$ERL -setcookie "$VAL""
                ;;
            --sname|--name)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                ERL="$ERL `echo $PEEK | cut -c 2-` "$VAL""
                ;;
            --logger-otp-reports)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                if [ "$VAL" = 'true' ] || [ "$VAL" = 'false' ]; then
                    ERL="$ERL -logger handle_otp_reports "$VAL""
                fi
                ;;
            --logger-sasl-reports)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                if [ "$VAL" = 'true' ] || [ "$VAL" = 'false' ]; then
                    ERL="$ERL -logger handle_sasl_reports "$VAL""
                fi
                ;;
            --erl)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                ERL="$ERL "$VAL""
                ;;
            *)
                break
                ;;
        esac
        I=$(expr $I + $S)
    done
    if [ "$MODE" != "iex" ]; then ERL="-noshell -s elixir start_cli $ERL"; fi
    erl $ELIXIR_ERL_OPTIONS $ERL -extra "$@"
}

# Run IEx
iex() {
    elixir --no-halt --erl "-noshell -user Elixir.IEx.CLI" +iex "$@"
}

# Echoes the current ERTS version
erts_vsn() {
    erl -eval 'Ver = erlang:system_info(version), io:format("~s~n", [Ver])' -noshell -s erlang halt
}

# Echoes the current ERTS root directory
erts_root() {
    erl -eval 'io:format("~s~n", [code:root_dir()]).' -noshell -s erlang halt
}

# Echoes the current OTP version
otp_vsn() {
    erl -eval 'Ver = erlang:system_info(otp_release), io:format("~s~n", [Ver])' -noshell -s erlang halt
}

# Use release_ctl for local operations
# Use like `release_ctl eval "IO.puts(\"Hi!\")"`
release_ctl() {
    command="$1"; shift
    elixir -e "Mix.Releases.Runtime.Control.main" \
           --erl "-boot $RELEASE_ROOT_DIR/bin/start_clean" \
           -- \
           "$command" "$@"
}

# Use release_ctl for remote operations
# Use like `release_remote_ctl ping`
release_remote_ctl() {
    command="$1"; shift
    name="${PEERNAME:-$NAME}"
    elixir -e "Mix.Releases.Runtime.Control.main" \
           -- \
           "$command" \
           --name="$name" \
           --cookie="$COOKIE" \
           "$@"
}

# DEPRECATED: Use release_remote_ctl instead
nodetool() {
    release_remote_ctl "$@"
}

# Run an escript in the node's environment
# Use like `escript "path/to/escript"`
escript() {
    scriptpath="$1"; shift
    export RELEASE_ROOT_DIR
    __escript="$(whereis_erts_bin)/escript"
    "$__escript" "$ROOTDIR/$scriptpath" "$@"
}

# Test erl to make sure it works
if erl -noshell -s erlang halt 2>/dev/null; then
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
    ERTS_LIB_DIR="$(readlink_f "$ERTS_DIR/../lib")"
    export EMU="beam"
    export PROGNAME="erl"
    # Initialize code paths
    __set_code_paths
else
    fail "Unusable Erlang runtime system! This is likely due to being compiled for another system than the host is running"
fi
