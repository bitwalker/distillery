defmodule Bundler.Utils.Logger do

  def configure(verbosity) when is_atom(verbosity) do
    Application.put_env(:bundler, :verbosity, verbosity)
  end

  @doc "Print an informational message in cyan"
  def debug(message),   do: log(:debug, "#{IO.ANSI.cyan}==> #{message}#{IO.ANSI.reset}")
  @doc "Print an informational message in bright cyan"
  def info(message),    do: log(:info, "#{IO.ANSI.bright}#{IO.ANSI.cyan}==> #{message}#{IO.ANSI.reset}")
  @doc "Print a success message in bright green"
  def success(message), do: log(:warn, "#{IO.ANSI.bright}#{IO.ANSI.green}==> #{message}#{IO.ANSI.reset}")
  @doc "Print a warning message in yellow"
  def warn(message),    do: log(:warn, "#{IO.ANSI.yellow}==> #{message}#{IO.ANSI.reset}")
  @doc "Print a notice in yellow"
  def notice(message),  do: log(:notice, "#{IO.ANSI.yellow}#{message}#{IO.ANSI.reset}")
  @doc "Print an error message in red"
  def error(message),   do: log(:error, "#{IO.ANSI.red}==> #{message}#{IO.ANSI.reset}")

  defp log(level, message),
    do: log(level, Application.get_env(:bundler, :verbosity, :normal), message)

  defp log(_, :verbose, message),         do: IO.puts message
  defp log(:error, :silent, message),     do: IO.puts message
  defp log(_level, :silent, _message),    do: :ok
  defp log(:debug, :quiet, _message),     do: :ok
  defp log(:debug, :normal, _message),    do: :ok
  defp log(:debug, _verbosity, message),  do: IO.puts message
  defp log(:info, :quiet, _message),      do: :ok
  defp log(:info, _verbosity, message),   do: IO.puts message
  defp log(_level, _verbosity, message),  do: IO.puts message

end
