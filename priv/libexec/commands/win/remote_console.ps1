## Attach a remote console

require-live-node

$id = gen-nodename

$bin = whereis-erts-bin
$werl = (join-path $bin werl)

$start_clean = "start_clean"
if ($bin.StartsWith($Env:RELEASE_ROOT_DIR)) {
    $start_clean = (join-path $Env:RELEASE_ROOT_DIR (join-path "bin" "start_clean"))
}

$argv = @("-hidden", "-noshell")
$argv += @("-boot", $start_clean)
$argv += @("-user", "Elixir.IEx.CLI")
$argv += @("-$Env:NAME_TYPE", $id)
$argv += @("-setcookie", $Env:COOKIE)
$argv += @("-extra", "--no-halt", "+iex")
$argv += @("--$Env:NAME_TYPE", $id)
$argv += @("--cookie", $Env:COOKIE)
$argv += @("--remsh", $Env:NAME)

& $werl @argv
