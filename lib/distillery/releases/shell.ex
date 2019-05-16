defmodule Distillery.Releases.Shell do
  @moduledoc """
  This module provides conveniences for writing output to the shell.
  """
  use Distillery.Releases.Shell.Macros

  @type verbosity :: :silent | :quiet | :normal | :verbose
  # The order of these levels is from least important to most important
  # When comparing log levels with `gte`, this ordering is what determines their total ordering
  deflevel(:debug, prefix: "==> ", color: :cyan)
  deflevel(:info, prefix: "==> ", color: [:bright, :cyan])
  deflevel(:notice, color: :yellow)
  deflevel(:success, prefix: "==> ", color: [:bright, :green])
  deflevel(:warn, prefix: "==> ", color: :yellow, error: :warnings_as_errors)
  deflevel(:error, prefix: "==> ", color: :red)

  @doc """
  Configure the logging verbosity of the release logger.

  Valid verbosity settings are:

      * `:silent`  - no output except errors
      * `:quiet`   - no output except warnings/errors
      * `:normal`  - no debug output (default)
      * `:verbose` - all output
  """
  @spec configure(verbosity) :: :ok
  def configure(verbosity) when is_atom(verbosity) do
    Application.put_env(:mix, :release_logger_verbosity, verbosity)
  end

  @default_answer_pattern ~r/^(y(es)?)?$/i

  @doc """
  Ask the user to confirm an action using the given message.
  The confirmation prompt will default to "[Yn]: ", and the
  regex for determining whether the action was confirmed will
  default to #{inspect(Regex.source(@default_answer_pattern))}.

  Use confirm/3 to provide your own prompt and answer regex.
  """
  @spec confirm?(String.t()) :: boolean
  def confirm?(message) do
    confirm?(message, "[Yn]: ", @default_answer_pattern)
  end

  @doc """
  Same as confirm/1, but takes a custom prompt and answer regex pattern.
  If the pattern matches the response, the action is considered confirmed.
  """
  @spec confirm?(String.t(), String.t(), Regex.t()) :: boolean
  def confirm?(message, prompt, answer_pattern) do
    IO.puts(IO.ANSI.format([:yellow]))
    answer = IO.gets("#{message} #{prompt}") |> String.trim_trailing("\n")
    IO.puts(IO.ANSI.format([:reset]))
    answer =~ answer_pattern
  end

  @doc """
  Prints an error message, then terminates the VM with a non-zero status code
  """
  @spec fail!(iodata) :: no_return
  def fail!(message) do
    error(message)
    System.halt(1)
  end

  @doc "Write the given iodata directly, bypassing the log level"
  def write(message),
    do: IO.write(message)

  @doc "Write the given iodata, wrapped in the given color, but bypassing the log level"
  def writef(message, color),
    do: write(colorf(message, color))

  @doc "Write a debug level message, but with minimal formatting. Default color is same as debug level"
  def debugf(message, color \\ :cyan) do
    data = verbosityf(:debug, colorf(message, color))
    IO.write(data)
  end

  ## Color helpers

  # Formats a message with a given color
  # Can use shorthand atoms for colors, or pass the ANSI directly
  @doc """
  Wraps a message in the given color
  """
  def colorf(message, color), do: IO.ANSI.format([color, message, :reset])
end
