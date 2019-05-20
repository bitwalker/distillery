## Run the app in console mode
$bin = whereis-erts-bin
$werl = (join-path $bin werl)

$boot = (join-path $Env:REL_DIR $Env:REL_NAME)

$argv = @("-boot", $boot)
$argv += @("-config", $Env:SYS_CONFIG_PATH)
$argv += @("-args_file", $Env:VMARGS_PATH)
$argv += @("-user", "Elixir.IEx.CLI")
$argv += @("-extra", "--no-halt", "+iex")

run-hooks -Phase pre_start

$post_start = {
    start-sleep -Second 2
    run-hooks -Phase post_start
}

# Run post-start hooks asynchronously
start-job -Name "post_start hooks" -ScriptBlock $post_start

$base_args = erl-args @argv

& $werl @base_args @argv
