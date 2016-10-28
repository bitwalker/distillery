defmodule Mix.Releases.Logger do
  @moduledoc """
  This is the logger implementation for Distillery. It is necessary to use
  because the process-based Logger in Elixir will drop messages when errors
  occur which kill the runtime, making debugging more difficult. We also
  colorize and format messages here.
  """

  @type verbosity :: :silent | :quiet | :normal | :verbose

  @doc """
  Configure the logging verbosity of the release logger.

  Valid verbosity settings are:

      - silent - no output except errors
      - quiet - no output except warnings/errors
      - normal - no debug output (default)
      - verbose - all output
  """
  @spec configure(verbosity) :: :ok
  def configure(verbosity) when is_atom(verbosity) do
    Application.put_env(:mix, :release_logger_verbosity, verbosity)
  end

  @debug_color   IO.ANSI.cyan
  @info_color    IO.ANSI.bright <> IO.ANSI.cyan
  @success_color IO.ANSI.bright <> IO.ANSI.green
  @warn_color    IO.ANSI.yellow
  @error_color   IO.ANSI.red

  @doc "Print a debug message in cyan"
  @spec debug(String.t) :: :ok
  def debug(message), do: log(:debug, colorize("==> #{message}", @debug_color))
  @doc "Print an unformatted debug message in cyan"
  @spec debug(String.t, :plain) :: :ok
  def debug(message, :plain), do: log(:debug, colorize(message, @debug_color))
  @doc "Print an informational message in bright cyan"
  @spec info(String.t) :: :ok
  def info(message), do: log(:info, colorize("==> #{message}", @info_color))
  @doc "Print a success message in bright green"
  @spec success(String.t) :: :ok
  def success(message), do: log(:warn, colorize("==> #{message}", @success_color))
  @doc "Print a warning message in yellow"
  @spec warn(String.t) :: :ok
  def warn(message) do
    case Application.get_env(:distillery, :warnings_as_errors) do
      true ->
        error(message)
        exit({:shutdown, 1})
      _ ->
        log(:warn, colorize("==> #{message}", @warn_color))
    end
  end
  @doc "Print a notice in yellow"
  @spec notice(String.t) :: :ok
  def notice(message),  do: log(:notice, colorize(message, @warn_color))
  @doc "Print an error message in red"
  @spec error(String.t) :: :ok
  def error(message), do: log(:error, colorize("==> #{message}", @error_color))

  defp log(level, message),
    do: log(level, Application.get_env(:mix, :release_logger_verbosity, :normal), message)

  defp log(_, :verbose, message),         do: IO.puts message
  defp log(:error, :silent, message),     do: IO.puts message
  defp log(_level, :silent, _message),    do: :ok
  defp log(:debug, :quiet, _message),     do: :ok
  defp log(:debug, :normal, _message),    do: :ok
  defp log(:info, :quiet, _message),      do: :ok
  defp log(_level, _verbosity, message),  do: IO.puts message

  defp colorize(message, color), do: IO.ANSI.format([color, message, IO.ANSI.reset])

end
