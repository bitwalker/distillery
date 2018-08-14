:: Execute rc command locally
@echo off

call %libexec_dir%\elixir.bat -e "Mix.Releases.Runtime.Control.main" -- %*
