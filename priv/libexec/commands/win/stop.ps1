## Stops a daemon started via `start`

require-live-node

run-hooks -Phase pre_stop

$service_name = ("{0}_{1}" -f $Env:REL_NAME,$Env:REL_VSN)

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")

& $erlsrv stop $service_name

if ($LastExitCode -ne 0) {
    exit 1
}

run-hooks -Phase post_stop
