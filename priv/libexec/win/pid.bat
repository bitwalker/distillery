@echo off
call %libexec_dir%\ping.bat
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
set override_boot_script=%none_boot_script%
call %libexec_dir%\release_remote_ctl.bat rpc "IO.inspect(:erlang.list_to_integer(:os.getpid()))"
