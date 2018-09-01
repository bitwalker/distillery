## Uninstalls the Windows service created by 'install'

#Requires -RunAsAdministrator

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")
$epmd = (join-path $bin "epmd.exe")

# With releases, service name must be '<nodename>_<release vsn>' per the docs
$nodename = $Env:NAME -replace "@.+$",""
$service_name = ("{0}_{1}" -f $nodename,$Env:REL_VSN)

& $erlsrv remove $service_name
if ($LastExitCode -ne 0) {
    exit 1
}

& $epmd -kill
