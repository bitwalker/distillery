Code.require_file("test/mix_test_helper.exs")

defmodule IntegrationTest do
  use ExUnit.Case, async: false

  alias Mix.Releases.Utils
  import MixTestHelper

  @newline Utils.newline()
  @standard_app_path Path.join([__DIR__, "fixtures", "standard_app"])
  @standard_output_path Path.join([__DIR__, "fixtures", "standard_app", "_build", "prod", "rel", "standard_app"])

  defmacrop with_standard_app(body) do
    quote do
      clean_up_standard_app!()
      old_dir = File.cwd!
      File.cd!(@standard_app_path)
      {:ok, _} = File.rm_rf(Path.join(@standard_app_path, "_build"))
      _ = File.rm(Path.join(@standard_app_path, "mix.lock"))
      {:ok, _} = mix("deps.get")
      {:ok, _} = mix("deps.compile", ["distillery"])
      {:ok, _} = mix("compile")
      {:ok, _} = mix("release.clean")
      unquote(body)
      File.cd!(old_dir)
    end
  end

  describe "standard application" do
    @tag :expensive
    @tag timeout: 60_000 * 5 # 5m
    test "can build release and start it" do
      with_standard_app do
        # Build release
        result = mix("release", ["--verbose", "--env=prod"])
        r = case result do
          {:ok, output} -> {:ok, output}
          {:error, _code, output} ->
            IO.puts(output)
            :error
        end
        assert {:ok, output} = r
        for callback <- ~w(before_assembly after_assembly before_package after_package) do
          assert output =~ "Prod Plugin - #{callback}"
        end
        refute String.contains?(output, "Release Plugin")

        assert ["0.0.1"] == Utils.get_release_versions(@standard_output_path)
        # Boot it, ping it, and shut it down
        assert {:ok, tmpdir} = Utils.insecure_mkdir_temp()
        bin_path = Path.join([tmpdir, "bin", "standard_app"])

        try do
          tarfile = Path.join([@standard_output_path, "releases", "0.0.1", "standard_app.tar.gz"])
          assert :ok = :erl_tar.extract('#{tarfile}', [{:cwd, '#{tmpdir}'}, :compressed])
          assert File.exists?(bin_path)
          case :os.type() do
            {:win32,_} ->
              assert {_output, 0} = System.cmd(bin_path, ["install"])
            _ ->
              :ok
          end

          :ok = create_additional_config_file(tmpdir)

          assert {_output, 0} = System.cmd(bin_path, ["start"])
          :timer.sleep(1_000) # Required, since starting up takes a sec
          assert {"pong\n", 0} = System.cmd(bin_path, ["ping"])
          assert {"2\n", 0}    = System.cmd(bin_path, ["eval", "'Elixir.Application':get_env(standard_app, num_procs)"])

          # Additional config items should exist
          assert {"bar\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.Application':get_env(standard_app, foo)"])

          case :os.type() do
            {:win32,_} ->
              assert {output, 0} = System.cmd(bin_path, ["stop"])
              assert String.contains?(output, "stopped")
              assert {_output, 0} = System.cmd(bin_path, ["uninstall"])
            _ ->
              assert {"ok\n", 0} = System.cmd(bin_path, ["stop"])
          end
        rescue
          e ->
            _ = System.cmd(bin_path, ["stop"])
            case :os.type() do
              {:win32,_} ->
                _ = System.cmd(bin_path, ["uninstall"])
              _ ->
                :ok
            end
            reraise e, System.stacktrace
        after
          File.rm_rf!(tmpdir)
          :ok
        end
      end
    end

    @tag :expensive
    @tag timeout: 60_000 * 5 # 5m
    test "can build and deploy hot upgrade" do
      with_standard_app do
        # Build v1 release
        result = mix("release", ["--verbose", "--env=prod"])
        r = case result do
              {:ok, output} -> {:ok, output}
              {:error, _code, output} ->
                IO.puts(output)
                :error
            end
        assert {:ok, _output} = r
        # Update config for v2
        project_config_path = Path.join(@standard_app_path, "mix.exs")
        project = File.read!(project_config_path)
        config_path = Path.join([@standard_app_path, "config", "config.exs"])
        config = File.read!(config_path)
        rel_config_path = Path.join([@standard_app_path, "rel", "config.exs"])
        rel_config = File.read!(rel_config_path)
        # Write updates to modules
        a_mod_path = Path.join([@standard_app_path, "lib", "standard_app", "a.ex"])
        a_mod = File.read!(a_mod_path)
        b_mod_path = Path.join([@standard_app_path, "lib", "standard_app", "b.ex"])
        b_mod = File.read!(b_mod_path)
        # Save orig
        File.cp!(project_config_path,
                 Path.join(@standard_app_path, "mix.exs.v1"))
        File.cp!(config_path,
                 Path.join([@standard_app_path, "config", "config.exs.v1"]))
        File.cp!(rel_config_path,
                 Path.join([@standard_app_path, "rel", "config.exs.v1"]))
        File.cp!(a_mod_path,
                 Path.join([@standard_app_path, "lib", "standard_app", "a.ex.v1"]))
        File.cp!(b_mod_path,
                 Path.join([@standard_app_path, "lib", "standard_app", "b.ex.v1"]))
        # Write new config
        new_project_config = String.replace(project, "version: \"0.0.1\"", "version: \"0.0.2\"")
        new_config = String.replace(config, "num_procs: 2", "num_procs: 4")
        new_rel_config = String.replace(rel_config, "set version: \"0.0.1\"", "set version: \"0.0.2\"")
        File.write!(project_config_path, new_project_config)
        File.write!(config_path, new_config)
        File.write!(rel_config_path, new_rel_config)
        # Write updated modules
        new_a_mod = String.replace(a_mod, "{:ok, {1, []}}", "{:ok, {2, []}}")
        new_b_mod = String.replace(b_mod, "loop({1, []}, parent, debug)", "loop({2, []}, parent, debug)")
        File.write!(a_mod_path, new_a_mod)
        File.write!(b_mod_path, new_b_mod)
        # Build v2 release
        {:ok, _} = mix("compile")
        result = mix("release", ["--verbose", "--env=prod", "--upgrade"])
        r = case result do
              {:ok, output} -> {:ok, output}
              {:error, _code, output} ->
                IO.puts(output)
                :error
            end
        assert {:ok, _} = r
        assert ["0.0.2", "0.0.1"] == Utils.get_release_versions(@standard_output_path)
        # Deploy it
        assert {:ok, tmpdir} = Utils.insecure_mkdir_temp()
        bin_path = Path.join([tmpdir, "bin", "standard_app"])
        try do
          tarfile = Path.join([@standard_output_path, "releases", "0.0.1", "standard_app.tar.gz"])
          assert :ok = :erl_tar.extract('#{tarfile}', [{:cwd, '#{tmpdir}'}, :compressed])
          File.mkdir_p!(Path.join([tmpdir, "releases", "0.0.2"]))
          File.cp!(Path.join([@standard_output_path, "releases", "0.0.2", "standard_app.tar.gz"]),
                  Path.join([tmpdir, "releases", "0.0.2", "standard_app.tar.gz"]))
          # Boot it, ping it, upgrade it, rpc to verify, then shut it down
          assert File.exists?(bin_path)
          case :os.type() do
            {:win32,_} ->
              assert {_output,0} = System.cmd(bin_path, ["install"])
            _ ->
              :ok
          end
          :ok = create_additional_config_file(tmpdir)
          assert {_output, 0} = System.cmd(bin_path, ["start"])
          :timer.sleep(1_000) # Required, since starting up takes a sec
          assert {"pong\n", 0} = System.cmd(bin_path, ["ping"])
          assert {"ok\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.StandardApp.A':push(1)"])
          assert {"ok\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.StandardApp.A':push(2)"])
          assert {"ok\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.StandardApp.B':push(1)"])
          assert {"ok\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.StandardApp.B':push(2)"])
          assert {output, 0} = System.cmd(bin_path, ["upgrade", "0.0.2"])
          expected = "Made release permanent: \"0.0.2\""
          result = String.contains?(output, expected)
          unless result do
            IO.inspect({:result, expected: expected, in: output})
          end
          assert true = result
          assert {"{ok,2}\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.StandardApp.A':pop()"])
          assert {"{ok,2}\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.StandardApp.B':pop()"])
          assert {"4\n", 0} = System.cmd(bin_path, ["eval", "'Elixir.Application':get_env(standard_app, num_procs)"])
          case :os.type() do
            {:win32,_} ->
              assert {output, 0} = System.cmd(bin_path, ["stop"])
              assert String.contains?(output, "stopped")
              assert {_,0} = System.cmd(bin_path, ["uninstall"])
            _ ->
              assert {"ok\n", 0} = System.cmd(bin_path, ["stop"])
              :ok
          end
        rescue
          e ->
            _ = System.cmd(bin_path, ["stop"])
            _ = System.cmd(bin_path, ["uninstall"])
            reraise e, System.stacktrace
        after
          File.rm_rf!(tmpdir)
          clean_up_standard_app!()
          :ok
        end
      end
    end
  end

  # Create a configuration file inside the release directory
  defp create_additional_config_file(directory) do
      extra_config_path = Path.join([directory, "extra.config"])
      extra_config = "[{standard_app, [{foo, bar}]}]."
      file = File.open!(extra_config_path, [:write, :utf8])
      IO.puts(file, extra_config)
      File.close(file)
  end

  defp clean_up_standard_app! do
    project_path = Path.join(@standard_app_path, "mix.exs.v1")
    if File.exists?(project_path) do
      File.cp!(project_path, Path.join(@standard_app_path, "mix.exs"))
      File.rm!(project_path)
    end
    config_path = Path.join([@standard_app_path, "config", "config.exs.v1"])
    if File.exists?(config_path) do
      File.cp!(config_path, Path.join([@standard_app_path, "config", "config.exs"]))
      File.rm!(config_path)
    end
    rel_config_path = Path.join([@standard_app_path, "rel", "config.exs.v1"])
    if File.exists?(rel_config_path) do
      File.cp!(rel_config_path, Path.join([@standard_app_path, "rel", "config.exs"]))
      File.rm!(rel_config_path)
    end
    a_mod_path = Path.join([@standard_app_path, "lib", "standard_app", "a.ex.v1"])
    if File.exists?(a_mod_path) do
      File.cp!(a_mod_path, Path.join([@standard_app_path, "lib", "standard_app", "a.ex"]))
      File.rm!(a_mod_path)
    end
    b_mod_path = Path.join([@standard_app_path, "lib", "standard_app", "b.ex.v1"])
    if File.exists?(b_mod_path) do
      File.cp!(b_mod_path, Path.join([@standard_app_path, "lib", "standard_app", "b.ex"]))
      File.rm!(b_mod_path)
    end
    File.rm_rf!(Path.join([@standard_app_path, "rel", "standard_app"]))
    :ok
  end
end
