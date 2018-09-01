## Install the release as a Windows service via erlsrv

$service_name = ("{0}_{1}" -f $Env:REL_NAME,$Env:REL_VSN)
$desc = "{0} version {1} running in {2}" -f $Env:REL_NAME,$Env:REL_VSN,$Env:RELEASE_ROOT_DIR

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")
$start_erl = (join-path $bin "start_erl.exe")

$erl_opts = string-to-argv -String $Env:ERL_OPTS

$service_args = @()
$service_args += $erl_opts
$service_args += @("-setcookie", "$Env:COOKIE")
$service_args += @("-pa", $Env:CONSOLIDATED_DIR)
$service_args += @("-rootdir", $Env:RELEASE_ROOT_DIR)
$service_args += @("-reldir", (join-path $Env:RELEASE_ROOT_DIR "releases"))

& $erlsrv add $service_name -c $desc ^
  -$Env:NAME_TYPE $Env:NAME ^
  -w $Env:RELEASE_MUTABLE_DIR ^
  -m $start_erl ^
  -args "$service_args" ^
  -debugtype new ^
  -stopaction "init:stop()."
