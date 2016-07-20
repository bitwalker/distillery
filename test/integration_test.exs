defmodule IntegrationTest do
  use ExUnit.Case, async: false

  alias Mix.Releases.Utils

  @standard_app_path Path.join([__DIR__, "fixtures", "standard_app"])
  @standard_output_path Path.join([__DIR__, "fixtures", "standard_app", "rel", "standard_app"])
  @umbrella_app_path Path.join([__DIR__, "fixtures", "umbrella_app"])

  defmacrop with_app(body) do
    quote do
      old_dir = File.cwd!
      File.cd!(@standard_app_path)
      unquote(body)
      File.cd!(old_dir)
    end
  end

  describe "standard application" do
    @tag :expensive
    @tag timeout: 120_000 # 2m
    test "can build release and start it" do
      with_app do
        # Build release
        {:ok, _} = File.rm_rf(Path.join(@standard_app_path, "_build"))
        _ = File.rm(Path.join(@standard_app_path, "mix.lock"))
        :ok = mix("deps.get")
        :ok = mix("deps.compile", ["distillery"])
        :ok = mix("compile")
        :ok = mix("release.clean")
        result = mix("release", ["--verbose", "--env=prod"])
        r = case result do
          :ok -> :ok
          {:error, _code, output} ->
            IO.puts(output)
            :error
        end
        assert :ok = r
        assert ["0.0.1"] == Utils.get_release_versions(@standard_output_path)
        # Boot it, ping it, and shut it down
        bin_path = Path.join([@standard_output_path, "bin", "standard_app"])
        assert File.exists?(bin_path)
        assert {_output, 0} = System.cmd(bin_path, ["start"])
        :timer.sleep(1_000) # Required, since starting up takes a sec
        assert {output, 0} = System.cmd(bin_path, ["ping"])
        assert String.contains?(output, "pong")
        assert {output, 0} = System.cmd(bin_path, ["stop"])
        assert String.contains?(output, "ok")
        sys_config_path = Path.join([@standard_output_path, "releases", "0.0.1", "sys.config"])
        assert {:ok, [sysconfig_content]} = Utils.read_terms(sys_config_path)
        assert 2 = get_in(sysconfig_content, [:standard_app, :num_procs])
      end
    end
  end

  # Call the elixir mix binary with the given arguments
  defp mix(command),       do: do_cmd(:prod, command)
  defp mix(command, args), do: do_cmd(:prod, command, args)

  defp do_cmd(env, command, args \\ []) do
    case System.cmd "mix", [command|args], env: [{"MIX_ENV", "#{env}"}] do
      {_output, 0} -> :ok
      {output, err} -> {:error, err, output}
    end
  end
end
