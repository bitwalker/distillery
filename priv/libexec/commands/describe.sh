#!/usr/bin/env bash

set -o posix

## Print a summary of information about this release

set -e

_load_cookie

echo "$REL_NAME-$REL_VSN"
echo "erts:        $ERTS_VSN"
echo "path:        $REL_DIR"
echo "sys.config:  $SYS_CONFIG_PATH"
echo "vm.args:     $VMARGS_PATH"
echo "name:        $NAME"
echo "cookie:      $COOKIE"
echo "erl_opts:    ${ERL_OPTS:-none provided}"
echo "run_erl_env: ${RUN_ERL_ENV:-none provided}"
echo ""
echo "hooks:"
__has_hooks=0
for hook in "$REL_DIR"/hooks/*.d/[0-9a-zA-Z]*.sh; do
    [ -f "$hook" ] || continue
    __has_hooks=1
    echo "$hook"
done
if [ "$__has_hooks" -eq 0 ]; then
    echo "No custom hooks found."
fi
echo ""
echo "commands:"
__has_commands=0
for command in "$REL_DIR"/commands/*.sh; do
    [ -f "$command" ] || continue
    __has_commands=1
    echo "$command"
done
if [ "$__has_commands" -eq 0 ]; then
    echo "No custom commands found."
fi
exit 0
