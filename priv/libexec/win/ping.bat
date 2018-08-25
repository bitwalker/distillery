@echo off
set peer="%node_name%"
if not "%~1"=="" (
  set peer="%~1"
)
call %libexec_dir%\release_ctl.bat ping --name="%peer%" --cookie="%cookie%"
