## Run the app in console mode
$bin = whereis-erts-bin
$erl = (join-path $bin "erl.exe") #get erl.exe as werl.exe will open a new window

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
start-job -Name "post_start hooks" -ScriptBlock $post_start | out-null # hide the output from start-job

start-process "$erl" -ArgumentList "$argv" -Wait -NoNewWindow #execute the application in the current shell window
