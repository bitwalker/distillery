if ($args.Length -gt 0) {
    # We should delegate this to the command tool
    release-ctl help @args
    exit
}

write-host (@"
USAGE
  {0} <task> [options] [args..]

COMMANDS"

  start                Start {0} as a daemon
  foreground           Start {0} in the foreground
  console              Start {0} with a console attached
  stop                 Stop the {0} daemon
  restart              Restart the {0} daemon without shutting down the VM
  reboot               Restart the {0} daemon
  upgrade <version>    Upgrade {0} to <version>
  downgrade <version>  Downgrade {0} to <version>
  remote_console       Remote shell to $REL_NAME's console
  reload_config        Reload the current system's configuration from disk
  pid                  Get the pid of the running $REL_NAME instance
  ping                 Checks if {0} is running, pong is returned if successful
  escript              Execute an escript
  rpc                  Execute Elixir code on the running node
  eval                 Execute Elixir code locally
  describe             Print useful information about the $REL_NAME release
"@ -f $Env:REL_NAME)

$commands = get-childitem -Directory (join-path $Env:REL_DIR "commands") -Filter "*.ps1" | foreach { $_.Name -replace ".ps1","" }
if ($commands.Length -gt 0) {
    $commands | foreach { write-host ("  {0} (custom command)" -f $_) }
} else {
    write-host "No custom commands found."
}
write-host
write-host ("Use '{0} help <task>' to get more information about a particular task (except custom commands)" -f $Env:REL_NAME)
exit
