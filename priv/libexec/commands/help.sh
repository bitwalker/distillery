#!/usr/bin/env bash

set -o posix

set -e

echo "Usage: $REL_NAME <task>"
echo
echo "Service Control"
echo "======================="
echo "start                          # start $REL_NAME as a daemon"
echo "start_boot <file>              # start $REL_NAME as a daemon, but supply a custom .boot file"
echo "foreground                     # start $REL_NAME in the foreground"
echo "console                        # start $REL_NAME with a console attached"
echo "console_clean                  # start a console with code paths set but no apps loaded/started"
echo "console_boot <file>            # start $REL_NAME with a console attached, but supply a custom .boot file"
echo "stop                           # stop the $REL_NAME daemon"
echo "restart                        # restart the $REL_NAME daemon without shutting down the VM"
echo "reboot                         # restart the $REL_NAME daemon"
echo "reload_config                  # reload the current system's configuration from disk"
echo
echo "Upgrades"
echo "======================="
echo "upgrade <version>              # upgrade $REL_NAME to <version>"
echo "downgrade <version>            # downgrade $REL_NAME to <version>"
echo "install <version>              # install the $REL_NAME-<version> release, but do not upgrade to it"
echo
echo "Utilities"
echo "======================="
echo "attach                         # attach the current TTY to $REL_NAME's console"
echo "remote_console                 # remote shell to $REL_NAME's console"
echo "pid                            # get the pid of the running $REL_NAME instance"
echo "ping                           # checks if $REL_NAME is running, pong is returned if successful"
echo "pingpeer <peer>                # check if a peer node is running, pong is returned if successful"
echo "escript <file>                 # execute an escript"
echo "rpc <mod> <fun> [<args..>]     # execute an RPC call using the given MFA"
echo "rpcterms <mod> <fun> [<expr>]  # execute an RPC call using the given Erlang expression for args"
echo "eval <expr>                    # execute the given Erlang expression on the running node"
echo "command <mod> <fun> [<args..>] # execute the given MFA"
echo "describe                       # print useful information about the $REL_NAME release"
echo
echo "Custom Commands"
echo "======================="
__has_commands=0
for command in "$REL_DIR"/commands/*.sh; do
    [ -f "$command" ] || continue
    __has_commands=1
    echo "$command"
done
if [ "$__has_commands" -eq 0 ]; then
    echo "No custom commands found."
fi
echo ""
exit 1
