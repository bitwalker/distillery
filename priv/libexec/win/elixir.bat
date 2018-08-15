:: Provide a subset of the 'elixir' script functionality
@echo off

%erl% -boot_var ERTS_LIB_DIR "%ERTS_LIB_DIR%" ^
      -boot "%clean_boot_script%" ^
      -config "%sys_config%" ^
      -pa "%consolidated_dir%" ^
      -noshell ^
      -s elixir start_cli ^
      -extra %*
