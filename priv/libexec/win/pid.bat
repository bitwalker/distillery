@echo off
call %libexec_dir%\ping.bat
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
call %libexec_dir%\release_remote_ctl.bat rpc "IO.inspect(:erlang.list_to_integer(:os.getpid()))"
