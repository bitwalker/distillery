## Install the release as a Windows service via erlsrv

#Requires -RunAsAdministrator

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
$service_argv += @("-boot_var", "ERTS_LIB_DIR", $Env:ERTS_LIB_DIR)
$service_argv += @("-config", $Env:SYS_CONFIG_PATH)
$service_argv += @("-setcookie", $Env:COOKIE)
# Add code paths
$codepaths = get-code-paths
$service_argv += "-pa"
$service_argv += $codepaths
$service_argv += @("-pa", $Env:CONSOLIDATED_DIR)
$base_argv = erl-args @service_argv
# Add start_erl opts, delimited by ++
$service_argv += "++"
$service_argv += "-noconfig"
$service_argv += @("-rootdir", $Env:RELEASE_ROOT_DIR)
$service_argv += @("-reldir", (join-path $Env:RELEASE_ROOT_DIR "releases"))
$service_argv += @("-data", "$Env:START_ERL_DATA)

$service_argv = $service_argv | foreach { 
    if ($_.StartsWith("-") -or $_.StartsWith("+")) {
        # Don't quote flags
        $_
    } else {
        ensure-quoted $_
    }
}

# Convert argv into a string for -args
$base_args = $base_argv -join " "
$service_args = $service_argv -join " "
$service_args = $base_args, $service_args -join " "

$name_type = ("-{0}" -f $Env:NAME_TYPE)

$argv = @("add", $service_name)
$argv += @("-comment", (ensure-quoted $desc))
$argv += @($name_type, $Env:NAME)
$argv += @("-workdir", $Env:RELEASE_ROOT_DIR)
$argv += @("-machine", $start_erl)
$argv += @("-stopaction", (ensure-quoted "init:stop()."))
$argv += @("-args", (ensure-quoted $service_args))

& $erlsrv @argv
