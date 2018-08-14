@echo off

:: Execute rc command remotely

set rc_cmd="%~1"
setlocal EnableDelayedExpansion
%libexec_dir%\elixir.bat -e "Mix.Releases.Runtime.Control.main" -- ^
             "%rc_cmd" ^
             --name="%node_name%" ^
             --cookie="!cookie!" ^
             %*
endlocal
