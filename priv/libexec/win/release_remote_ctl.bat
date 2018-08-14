:: Execute rc command remotely
@echo off

set rc_cmd="%1"
shift /1

set rc_args=
setlocal EnableDelayedExpansion
:rc_parse_args
set param=%~1
set param=%param:(=^^(%
set param=%param:)=^^)%
if "%~1"=="" goto :rc_args_parsed
if "!rclargs!"=="" (
  set rclargs=%param:"=\"%
) else (
  set rclargs=%rclargs% %param:"=\"%
)
set "delim= "
shift /1
goto :rc_parse_args
:rc_args_parsed
endlocal & set rc_args=%rclargs%

setlocal EnableDelayedExpansion
call %libexec_dir%\elixir.bat -e "Mix.Releases.Runtime.Control.main" -- ^
             "%rc_cmd%" ^
             --name="%node_name%" ^
             --cookie="!cookie!" ^
             %rc_args%
endlocal
