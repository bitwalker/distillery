@echo off
set peer="%node_name%"
if not "%~1"=="" (
  set peer="%~1"
)
set override_boot_script=%none_boot_script%
call %libexec_dir%\release_ctl.bat ping --peer="%peer%" --cookie="%cookie%"
