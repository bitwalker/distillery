## Restart the VM completely

require-live-node

$service_name = ("{0}_{1}" -f $Env:REL_NAME,$Env:REL_VSN)

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")

# Stop first
run-hooks -Phase pre_stop
& $erlsrv stop $service_name
if ($LastExitCode -ne 0) {
    exit 1
}
run-hooks -Phase post_stop

# Restart
run-hooks -Phase pre_start
& $erlsrv start $service_name
if ($LastExitCode -ne 0) {
    exit 1
}
run-hooks -Phase post_start
