#!/usr/bin/env bash

set -e

if [ ! -z "$1" ]; then
    # We should delegate this to the command tool
    release_ctl help "$@"
    exit 1
fi

echo "USAGE"
echo "  $REL_NAME <task> [options] [args..]"
echo
echo "COMMANDS"
echo
echo "  start                Start $REL_NAME as a daemon"
echo "  start_boot <file>    Start $REL_NAME as a daemon, but supply a custom .boot file"
echo "  foreground           Start $REL_NAME in the foreground"
echo "  console              Start $REL_NAME with a console attached"
echo "  console_clean        Start a console with code paths set but no apps loaded/started"
echo "  console_boot <file>  Start $REL_NAME with a console attached, but supply a custom .boot file"
echo "  stop                 Stop the $REL_NAME daemon"
echo "  restart              Restart the $REL_NAME daemon without shutting down the VM"
echo "  reboot               Restart the $REL_NAME daemon"
echo "  upgrade <version>    Upgrade $REL_NAME to <version>"
echo "  downgrade <version>  Downgrade $REL_NAME to <version>"
echo "  attach               Attach the current TTY to $REL_NAME's console"
echo "  remote_console       Remote shell to $REL_NAME's console"
echo "  reload_config        Reload the current system's configuration from disk"
echo "  pid                  Get the pid of the running $REL_NAME instance"
echo "  ping                 Checks if $REL_NAME is running, pong is returned if successful"
echo "  pingpeer <peer>      Check if a peer node is running, pong is returned if successful"
echo "  escript              Execute an escript"
echo "  rpc                  Execute Elixir code on the running node"
echo "  eval                 Execute Elixir code locally"
echo "  describe             Print useful information about the $REL_NAME release"
__has_commands=0
for command in "$REL_DIR"/commands/*.sh; do
    [ -f "$command" ] || continue
    __has_commands=1
    echo "  $(basename ${command%.*}) (custom command)"
done
if [ "$__has_commands" -eq 0 ]; then
    echo 
    echo "No custom commands found."
fi
echo
echo "Use $REL_NAME help <task> to get more information about a particular task (except custom commands)"
exit 1
