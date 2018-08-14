if "%~1"=="" (
  echo "Peer name is required!"
  exit /b 1
)
call %libexec_dir%\ping.bat %*
