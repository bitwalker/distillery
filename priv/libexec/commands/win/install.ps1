## Install the release as a Windows service via erlsrv

require-cookie

# With releases, service name must be '<nodename>_<release vsn>' per the docs
$nodename = $Env:NAME -replace "@.+$",""
$service_name = ("{0}_{1}" -f $nodename,$Env:REL_VSN)

$desc = "{0} version {1} running in {2}" -f $Env:REL_NAME,$Env:REL_VSN,$Env:RELEASE_ROOT_DIR

$bin = whereis-erts-bin
$erlsrv = (join-path $bin "erlsrv.exe")
$start_erl = (join-path $bin "start_erl.exe")

$erl_opts = string-to-argv -String $Env:ERL_OPTS

$service_argv = @()
$service_argv += $erl_opts
$service_argv += @("-config", $Env:SYS_CONFIG_PATH)
$service_argv += @("-setcookie", $Env:COOKIE)
$service_argv += @("-pa", $Env:CONSOLIDATED_DIR)
$service_argv += "-pa"
$codepaths = get-code-paths
$service_argv += $codepaths
$service_argv += "++"
$service_argv += @("-rootdir", $Env:RELEASE_ROOT_DIR)
$service_argv += @("-reldir", (join-path $Env:RELEASE_ROOT_DIR "releases"))

$service_args = ($service_argv | foreach { ("`"{0}`"" -f $_) }) -join " "

$name_type = ("-{0}" -f $Env:NAME_TYPE)

$argv = @("add", $service_name)
$argv += @("-comment", $desc)
$argv += @($name_type, $Env:NAME)
$argv += @("-workdir", $Env:RELEASE_ROOT_DIR)
$argv += @("-machine", $start_erl)
$argv += @("-debugtype", "new")
$argv += @("-stopaction", "init:stop().")
$argv += @("-args", $service_args)

& $erlsrv @argv
