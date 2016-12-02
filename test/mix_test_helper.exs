defmodule MixTestHelper do

  # Call the elixir mix binary with the given arguments
  def mix(command),       do: do_cmd(:prod, command)
  def mix(command, args), do: do_cmd(:prod, command, args)

  def do_cmd(env, command, args \\ []) do
    case System.cmd "mix", [command|args], env: [{"MIX_ENV", "#{env}"}] do
      {output, 0} ->
        if System.get_env("VERBOSE_TESTS") do
          IO.puts(output)
        end
        {:ok, output}
      {output, err} -> {:error, err, output}
    end
  end
end
