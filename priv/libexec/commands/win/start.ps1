## Starts the Windows service created by 'install'

# With releases, service name must be '<nodename>_<release vsn>' per the docs
$nodename = $Env:NAME -replace "@.+$",""
$service_name = ("{0}_{1}" -f $nodename,$Env:REL_VSN)

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")

run-hooks -Phase pre_start

& $erlsrv start $service_name

if ($LastExitCode -ne 0) {
    exit 1
}

run-hooks -Phase post_start
