defmodule Distillery.Releases.Appup.TransformError do
  @moduledoc """
  This error is raised when an appup transformation results in an
  invalid appup instruction or instruction set.
  """
  defexception [:message, :module, :callback]

  @doc false
  def exception(opts) do
    m = Keyword.fetch!(opts, :module)
    cb = Keyword.fetch!(opts, :callback)

    case Keyword.fetch!(opts, :error) do
      {:invalid_instruction, :restart_new_emulator} ->
        msg =
          "The appup transformation #{m}.#{cb}/5 incorrectly " <>
            "placed :restart_new_emulator which must always be the first instruction"

        %__MODULE__{message: msg, module: m, callback: cb}

      {:invalid_instruction, :restart_emulator} ->
        msg =
          "The appup transformation #{m}.#{cb}/5 incorrectly " <>
            "placed :restart_emulator which must always be the last instruction"

        %__MODULE__{message: msg, module: m, callback: cb}

      {:invalid_instruction, i} ->
        msg =
          "The appup transformation #{m}.#{cb}/5 generated an invalid instruction " <>
            "(#{inspect(i)}).\n" <>
            "Please review http://erlang.org/doc/design_principles/release_handling.html for a listing of valid instructions"

        %__MODULE__{message: msg, module: m, callback: cb}

      {:invalid_return, val} ->
        msg =
          "The appup transformation #{m}.#{cb}/5 returned an invalid value.\n" <>
            "  Expected a list of appup instructions, but got: #{inspect(val)}"

        %__MODULE__{message: msg, module: m, callback: cb}
    end
  end
end
