## Pings the running node, or an arbitrary peer node
## by supplying `--name` and `--cookie` flags.
##
## If the node is running and can be connected to,
## 'pong' will be printed to stdout. If the node is
## not reachable or cannot be connected to due to an
## invalid cookie, 'pang' will be printed to stdout
## and the command will exit with a non-zero status code.

require-cookie

$argv = @()
$argv += "--name=$Env:NAME"
$argv += "--cookie=$Env:COOKIE"
$argv += $args

release-ctl ping $argv
if ($LastExitCode -ne 0) {
    exit 1
}
