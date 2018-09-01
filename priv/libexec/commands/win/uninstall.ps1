## Uninstalls the Windows service created by 'install'

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")
$epmd = (join-path $bin "epmd.exe")
$service_name = ("{0}_{1}" -f $Env:REL_NAME,$Env:REL_VSN)

& $erlsrv remove $service_name
if ($LastExitCode -ne 0) {
    exit 1
}

& $epmd -kill
