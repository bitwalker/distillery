defmodule MixTestHelper do
  @moduledoc false

  @doc """
  Call the elixir mix binary with the given arguments
  """
  @spec mix(String.t()) :: {:ok, String.t()} | {:error, integer, String.t()}
  @spec mix(String.t(), [String.t()]) :: {:ok, String.t()} | {:error, integer, String.t()}
  def mix(command), do: do_cmd(:prod, command)
  def mix(command, args), do: do_cmd(:prod, command, args)

  defp do_cmd(env, command, args \\ []) do
    case System.cmd("mix", [command | args], env: [{"MIX_ENV", "#{env}"}]) do
      {output, 0} ->
        if System.get_env("VERBOSE_TESTS") do
          IO.puts(output)
        end

        {:ok, output}

      {output, err} ->
        if System.get_env("VERBOSE_TESTS") do
          IO.puts(output)
        end

        {:error, err, output}
    end
  end
end
