:: Provide a subset of the 'elixir' script functionality
@echo off

set desired_boot_script=
if "%override_boot_script%"=="" (
  set desired_boot_script=%clean_boot_script%
) else (
  set desired_boot_script=%override_boot_script%
  set override_boot_script=
)

%erl% -boot_var ERTS_LIB_DIR "%ERTS_LIB_DIR%" ^
      -boot "%desired_boot_script%" ^
      -config "%sys_config%" ^
      -pa "%consolidated_dir%" ^
      -noshell ^
      -s elixir start_cli ^
      -extra %*
