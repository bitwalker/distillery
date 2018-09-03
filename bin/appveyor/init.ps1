choco install erlang
if ($LastExitCode -ne 0) { exit 1 }

choco install elixir
if ($LastExitCode -ne 0) { exit 1 }

[Environment]::SetEnvironmentVariable("PATH", "C:\ProgramData\chocolatey\lib\Elixir\bin;C:\ProgramData\chocolatey\bin;$Env:PATH", "User")

refreshenv

# Locate the epmd executable and start it as a daemon
ls 'C:\Program Files\erl10*' | select-string 'erts-\d+\.\d+\.\d+' | foreach { & (join-path $_ "bin" "epmd.exe") -daemon }
if ($LastExitCode -ne 0) { exit 1 }
