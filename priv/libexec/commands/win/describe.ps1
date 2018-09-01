## Print a summary of information about this release

load-cookie

$describe_args = @()
$describe_args += ('--release-root-dir="{0}"' -f $Env:RELEASE_ROOT_DIR)
$describe_args += ('--release="{0}"' -f $Env:REL_NAME)
$describe_args += ('--name="{0}"' -f $Env:NAME)
$describe_args += ('--cookie="{0}"' -f $Env:COOKIE)
$describe_args += ('--sysconfig="{0}"' -f $Env:SYS_CONFIG_PATH)
$describe_args += ('--vmargs="{0}"' -f $Env:VMARGS_PATH)
$describe_args += ('--erl-opts="{0}"' -f $Env:ERL_OPTS)
$describe_args += ('--run-erl-env="{0}"' -f $Env:RUN_ERL_ENV)

release-ctl describe @describe_args
