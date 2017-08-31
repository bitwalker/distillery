#!/usr/bin/env bash

set -o posix

# Execute as command-line utility
#
# Like the escript command, this does not start the OTP application.
# If your command depends on a running OTP application,
# use the following in your Elixir code.
#
#     {:ok, _} = Application.ensure_all_started(:your_app)

set -e

require_cookie

MODULE="$1"; shift
FUNCTION="$1"; shift

# Save extra arguments
ARGS=$*

__code_paths=$(_get_code_paths)

# Checks is a module/function pair is defined
is_function_defined() {
    if [ -z "$1" ]; then
        fail "No module name was provided to is_function_defined, please report this issue on the tracker!"
    fi
    if [ -z "$2" ]; then
        fail "No function name was provided to is_function_defined, please report this issue on the tracker!"
    fi
    erl -eval "code:ensure_modules_loaded(['$1']), io:format(\"~p~n\", [erlang:function_exported('$1', $2, 0)]), halt()" \
        -noshell \
        -boot start_clean \
        -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR" \
        -pa "$CONSOLIDATED_DIR" \
        ${__code_paths}
}

# Build arguments for erlexec
[ "$SYS_CONFIG_PATH" ] && set -- -config "$SYS_CONFIG_PATH"
set -- "$@" -boot_var ERTS_LIB_DIR "$ERTS_LIB_DIR"
set -- "$@" -noshell
set -- "$@" -boot start_clean
set -- "$@" -pa "$CONSOLIDATED_DIR"
set -- "$@" ${__code_paths}
set -- "$@" -s "$MODULE" "$FUNCTION"

__is_defined=$(is_function_defined "$MODULE" "$FUNCTION")
if [ "$__is_defined" = "false" ]; then
    fail "$MODULE.$FUNCTION is either not defined or has a non-zero arity"
fi

"$BINDIR"/erlexec "$@" -s init stop $ERL_OPTS -extra $ARGS
exit "$?"
