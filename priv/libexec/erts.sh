#!/usr/bin/env bash

set -e

__rel_apps() {
    __releases="$RELEASE_ROOT_DIR/releases/RELEASES"
    __vsn="${REL_VSN//+/\\\+}"
    __rel="$(sed -E -n "/\{release,[^,]*,\"$__vsn\"/,/[^po]*(permanent|old)}/p" "$__releases")"
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

# Used post-upgrade to update the code paths used for commands
reset_code_paths() {
    code_paths=()
    __set_code_paths
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
    __bin="$(whereis_erts_bin)"
    if [ -z "$__bin" ]; then
        fail "Erlang runtime not found. If Erlang is installed, ensure it is in your PATH"
    fi
    __erl="$__bin/erl"
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
                 ${SYS_CONFIG_PATH:+-config "${SYS_CONFIG_PATH}"} \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${EXTRA_CODE_PATHS:+-pa "${EXTRA_CODE_PATHS}"} \
                 "$@"
    elif [ $__erts_included -eq 1 ]; then
        # Bundled ERTS, using default boot script 'start_clean'
        "$__erl" -boot_var ERTS_LIB_DIR "$RELEASE_ROOT_DIR/lib" \
                 -boot "${RELEASE_ROOT_DIR}/bin/start_clean" \
                 ${SYS_CONFIG_PATH:+-config "${SYS_CONFIG_PATH}"} \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${EXTRA_CODE_PATHS:+-pa "${EXTRA_CODE_PATHS}"} \
                 "$@"
    elif [ $__boot_provided -eq 0 ]; then
        # Host ERTS with -boot not set
        "$__erl" -boot start_clean \
                 ${SYS_CONFIG_PATH:+-config "${SYS_CONFIG_PATH}"} \
                 "${code_paths[@]}" \
                 -pa "${RELEASE_ROOT_DIR}"/lib/*/ebin \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${EXTRA_CODE_PATHS:+-pa "${EXTRA_CODE_PATHS}"} \
                 "$@"
    elif [ -z "$ERTS_LIB_DIR" ]; then
        # Host ERTS, -boot set, no ERTS_LIB_DIR available
        "$__erl" \
                 ${SYS_CONFIG_PATH:+-config "${SYS_CONFIG_PATH}"} \
                 "${code_paths[@]}" \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${EXTRA_CODE_PATHS:+-pa "${EXTRA_CODE_PATHS}"} \
                 "$@"
    else
        # Host ERTS, -boot set, ERTS_LIB_DIR available
        "$__erl" -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
                 ${SYS_CONFIG_PATH:+-config "${SYS_CONFIG_PATH}"} \
                 "${code_paths[@]}" \
                 -pa "${CONSOLIDATED_DIR}" \
                 ${EXTRA_CODE_PATHS:+-pa "${EXTRA_CODE_PATHS}"} \
                 "$@"
    fi
}

erlexec(){
    __erl="$(whereis_erts_bin)/erl"
    if [ -z "$__erl" ]; then
        fail "Erlang runtime not found. If Erlang is installed, ensure it is in your PATH"
    fi
    if [[ "$__erl" =~ ^$RELEASE_ROOT_DIR ]]; then
        # Bundled ERTS
        exec "$BINDIR/erlexec" -boot_var ERTS_LIB_DIR "$RELEASE_ROOT_DIR/lib" \
                               ${SYS_CONFIG_PATH:+-config "${SYS_CONFIG_PATH}"} \
                               -pa "${CONSOLIDATED_DIR}" \
                               ${EXTRA_CODE_PATHS:+-pa "${EXTRA_CODE_PATHS}"} \
                               "$@"
    else
        # Host ERTS
        exec "$BINDIR/erlexec" -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
                               ${SYS_CONFIG_PATH:+-config "${SYS_CONFIG_PATH}"} \
                               -pa "${RELEASE_ROOT_DIR}"/lib/*/ebin \
                               -pa "${CONSOLIDATED_DIR}" \
                               ${EXTRA_CODE_PATHS:+-pa "${EXTRA_CODE_PATHS}"} \
                               "$@"
    fi
}

# Stores erl arguments preserving spaces/quotes (mimics an array)
erlarg() {
  eval "E${E}=\$1"
  E=$((E + 1))
}

# Run Elixir
elixir() {
    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      cat <<USAGE >&2
Usage: $(basename "$0") [options] [.exs file] [data]

## General options

  -e "COMMAND"                 Evaluates the given command (*)
  -h, --help                   Prints this message and exits
  -r "FILE"                    Requires the given files/patterns (*)
  -S SCRIPT                    Finds and executes the given script in \$PATH
  -pr "FILE"                   Requires the given files/patterns in parallel (*)
  -pa "PATH"                   Prepends the given path to Erlang code path (*)
  -pz "PATH"                   Appends the given path to Erlang code path (*)
  -v, --version                Prints Elixir version and exits
  --app APP                    Starts the given app and its dependencies (*)
  --erl "SWITCHES"             Switches to be passed down to Erlang (*)
  --eval "COMMAND"             Evaluates the given command, same as -e (*)
  --logger-otp-reports BOOL    Enables or disables OTP reporting
  --logger-sasl-reports BOOL   Enables or disables SASL reporting
  --no-halt                    Does not halt the Erlang VM after execution
  --werl                       Uses Erlang's Windows shell GUI (Windows only)

Options given after the .exs file or -- are passed down to the executed code.
Options can be passed to the Erlang runtime using \$ELIXIR_ERL_OPTIONS or --erl.

## Distribution options

The following options are related to node distribution.
  --cookie COOKIE              Sets a cookie for this distributed node
  --hidden                     Makes a hidden node
  --name NAME                  Makes and assigns a name to the distributed node
  --rpc-eval NODE "COMMAND"    Evaluates the given command on the given remote node (*)
  --sname NAME                 Makes and assigns a short name to the distributed node

## Release options

The following options are generally used under releases.
  --boot "FILE"                Uses the given FILE.boot to start the system
  --boot-var VAR "VALUE"       Makes \$VAR available as VALUE to FILE.boot (*)
  --erl-config "FILE"          Loads configuration in FILE.config written in Erlang (*)
  --pipe-to "PIPEDIR" "LOGDIR" Starts the Erlang VM as a named PIPEDIR and LOGDIR
  --vm-args "FILE"             Passes the contents in file as arguments to the VM

--pipe-to starts Elixir detached from console (Unix-like only).
It will attempt to create PIPEDIR and LOGDIR if they don't exist.
See run_erl to learn more. To reattach, run: to_erl PIPEDIR.

** Options marked with (*) can be given more than once.
USAGE
          exit 1
        fi
    MODE="elixir"
    ERL=""
    I=1
    E=0
    LENGTH=$#
    set -- "$@" -extra
    while [ $I -le $LENGTH ]; do
        S=1
        case "$1" in
            +iex)
                set -- "$@" "$1"
                MODE="iex"
                ;;
            +elixirc)
                set -- "$@" "$1"
                MODE="elixirc"
                ;;
            -v|--no-halt)
                set -- "$@" "$1"
                ;;
            -e|-r|-pr|-pa|-pz|--app|--eval|--remsh|--dot-iex)
                S=2
                set -- "$@" "$1" "$2"
                ;;
            --rpc-eval)
                S=3
                set -- "$@" "$1" "$2" "$3"
                ;;
            --detatched)
                echo "warning: the --detached option is deprecated" >&2
                ERL="$ERL -detached"
                ;;
            --hidden)
                ERL="$ERL -hidden"
                ;;
            --logger-otp-reports)
                S=2
                if [ "$2" = 'true' ] || [ "$2" = 'false' ]; then
                    ERL="$ERL -logger handle_otp_reports $2"
                fi
                ;;
            --logger-sasl-reports)
                S=2
                if [ "$2" = 'true' ] || [ "$2" = 'false' ]; then
                    ERL="$ERL -logger handle_sasl_reports $2"
                fi
                ;;
            --erl)
                S=2
                ERL="$ERL $2"
                ;;
            --cookie)
                S=2
                erlarg "-setcookie"
                erlarg "$2"
                ;;
            --sname|--name)
                S=2
                erlarg "$(echo "$1" | cut -c 2-)"
                erlarg "$2"
                ;;
            --erl-config)
                S=2
                erlarg "-config"
                erlarg "$2"
                ;;
            --vm-args)
                S=2
                erlarg "-args_file"
                erlarg "$2"
                ;;
            --boot)
                S=2
                erlarg "-boot"
                erlarg "$2"
                ;;
            --boot-var)
                S=3
                erlarg "-boot_var"
                erlarg "$2"
                erlarg "$3"
                ;;
            --pipe-to)
                S=3
                RUN_ERL_PIPE="$2"
                RUN_ERL_LOG="$3"
                if [ "$(starts_with "$RUN_ERL_PIPE" "-")" ]; then
                  echo "--pipe-to : PIPEDIR cannot be a switch" >&2 && exit 1
                elif [ "$(starts_with "$RUN_ERL_LOG" "-")" ]; then
                  echo "--pipe-to : LOGDIR cannot be a switch" >&2 && exit 1
                fi
                ;;
            --werl)
                ;;
            *)
                while [ $I -le $LENGTH ]; do
                    I=$((I + 1))
                    set -- "$@" "$1"
                    shift
                done
                break
                ;;
        esac
        I=$((I + S))
        shift $S
    done

    I=$((E - 1))
    while [ $I -ge 0 ]; do
      eval "VAL=\$E$I"
      set -- "$VAL" "$@"
      I=$((I - 1))
    done

    if [ "$MODE" != "iex" ]; then ERL="-noshell -s elixir start_cli $ERL"; fi
    #shellcheck disable=2086
    erl $ELIXIR_ERL_OPTIONS $ERL "$@"
}

# Run IEx
iex() {
    elixir --no-halt --erl "-noshell -user Elixir.IEx.CLI" +iex "$@"
}

# Echoes the current ERTS version
erts_vsn() {
    erl -noshell \
        -eval 'Ver = erlang:system_info(version), io:format("~s~n", [Ver])' \
        -s erlang halt
}

# Echoes the current ERTS root directory
erts_root() {
    erl -noshell \
        -eval 'io:format("~s~n", [code:root_dir()]).' \
        -s erlang halt
}

# Echoes the current OTP version
otp_vsn() {
    erl -noshell \
        -eval 'Ver = erlang:system_info(otp_release), io:format("~s~n", [Ver])' \
        -s erlang halt
}

# Use release_ctl for local operations
# Use like `release_ctl eval "IO.puts(\"Hi!\")"`
release_ctl() {
    command="$1"; shift
    elixir -e "Distillery.Releases.Runtime.Control.main" \
           --logger-sasl-reports false \
           -- \
           "$command" "$@"
}

# Use release_ctl for remote operations
# Use like `release_remote_ctl ping`
release_remote_ctl() {
    require_cookie

    command="$1"; shift
    name="${PEERNAME:-$NAME}"
    elixir -e "Distillery.Releases.Runtime.Control.main" \
           --logger-sasl-reports false \
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

# Test erl to make sure it works, extract key info about runtime while doing so
if __info="$(erl -noshell -eval 'io:format("~s~n~s~n", [code:root_dir(), erlang:system_info(version)]).' -s erlang halt)"; then
    export ROOTDIR
    ROOTDIR="$(echo "$__info" | head -n1)"
    export ERTS_VSN
    if [ -z "$ERTS_VSN" ]; then
        if [ ! -f "${START_ERL_DATA}" ]; then
            fail "Unable to boot release, missing start_erl.data at '${START_ERL_DATA}'"
        fi
        # Update start_erl.data
        ERTS_VSN="$(echo "$__info" | tail -n1)"
        echo "$ERTS_VSN $REL_VSN" > "$START_ERL_DATA"
    else
        ERTS_VSN="$(echo "$__info" | tail -n1)"
    fi
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
