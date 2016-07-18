defmodule Mix.Releases.Logger do

  def configure(verbosity) when is_atom(verbosity) do
    Application.put_env(:mix, :release_logger_verbosity, verbosity)
  end

  @debug_color   IO.ANSI.cyan
  @info_color    IO.ANSI.bright <> IO.ANSI.cyan
  @success_color IO.ANSI.bright <> IO.ANSI.green
  @warn_color    IO.ANSI.yellow
  @error_color   IO.ANSI.red

  @doc "Print an informational message in cyan"
  def debug(message),         do: log(:debug, colorize("==> #{message}", @debug_color))
  def debug(message, :plain), do: log(:debug, colorize(message, @debug_color))
  @doc "Print an informational message in bright cyan"
  def info(message),    do: log(:info, colorize("==> #{message}", @info_color))
  @doc "Print a success message in bright green"
  def success(message), do: log(:warn, colorize("==> #{message}", @success_color))
  @doc "Print a warning message in yellow"
  def warn(message),    do: log(:warn, colorize("==> #{message}", @warn_color))
  @doc "Print a notice in yellow"
  def notice(message),  do: log(:notice, colorize(message, @warn_color))
  @doc "Print an error message in red"
  def error(message),   do: log(:error, colorize("==> #{message}", @error_color))

  defp log(level, message),
    do: log(level, Application.get_env(:mix, :release_logger_verbosity, :normal), message)

  defp log(_, :verbose, message),         do: IO.puts message
  defp log(:error, :silent, message),     do: IO.puts message
  defp log(_level, :silent, _message),    do: :ok
  defp log(:debug, :quiet, _message),     do: :ok
  defp log(:debug, :normal, _message),    do: :ok
  defp log(:debug, _verbosity, message),  do: IO.puts message
  defp log(:info, :quiet, _message),      do: :ok
  defp log(:info, _verbosity, message),   do: IO.puts message
  defp log(_level, _verbosity, message),  do: IO.puts message

  defp colorize(message, color), do: "#{color}#{message}#{IO.ANSI.reset}"

end
