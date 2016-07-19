defmodule Distillery.IO do
  @moduledoc false

  @default_answer_pattern ~r/^(y(es)?)?$/i

  @doc """
  Ask the user to confirm an action using the given message.
  The confirmation prompt will default to "[Yn]: ", and the
  regex for determining whether the action was confirmed will
  default to #{inspect Regex.source(@default_answer_pattern)}.

  Use confirm/3 to provide your own prompt and answer regex.
  """
  @spec confirm(String.t) :: boolean
  def confirm(message) do
    confirm(message, "[Yn]: ", @default_answer_pattern)
  end

  @doc """
  Same as confirm/1, but takes a custom prompt and answer regex pattern.
  If the pattern matches the response, the action is considered confirmed.
  """
  @spec confirm(String.t, String.t, Regex.t) :: boolean
  def confirm(message, prompt, answer_pattern) do
    IO.puts IO.ANSI.yellow
    answer = IO.gets("#{message} #{prompt}") |> String.rstrip(?\n)
    IO.puts IO.ANSI.reset
    answer =~ answer_pattern
  end
end
