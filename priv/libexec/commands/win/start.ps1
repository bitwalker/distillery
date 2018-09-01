## Starts the Windows service created by 'install'
$service_name = ("{0}_{1}" -f $Env:REL_NAME,$Env:REL_VSN)

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")

run-hooks -Phase pre_start

& $erlsrv start $service_name

if ($LastExitCode -ne 0) {
    exit 1
}

run-hooks -Phase post_start
