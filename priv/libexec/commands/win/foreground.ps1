## This command starts the release in the foreground, i.e.
## standard out is routed to the current terminal session.

require-cookie

# Start the VM, executing pre and post start hooks
run-hooks -Phase pre_start

$boot = (join-path $Env:REL_DIR $Env:REL_NAME)

$post_start = {
    start-sleep -Second 2
    run-hooks -Phase post_start
}

# Build argument vector for erl
$erl_opts = @()
if ($Env:ERL_OPTS -ne $null) {
    $erl_opts = string-to-argv -String $Env:ERL_OPTS
}
$extra_opts = @()
if ($Env:EXTRA_OPTS -ne $null) {
    $extra_opts = string-to-argv -String $Env:EXTRA_OPTS
}

$argv = @("-noshell", "-noinput", "+Bd")
$argv += @("-boot", $boot)
$argv += @("-args_file", "$Env:VMARGS_PATH")
$argv += @("-mode", "embedded")
$argv += $erl_opts
$argv += "-extra"
$argv += $extra_opts
$argv += $args

# Run post-start hooks asynchronously
start-job -Name "post_start hooks" -ScriptBlock $post_start

erl @argv
