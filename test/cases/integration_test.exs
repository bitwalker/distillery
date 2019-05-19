defmodule Distillery.Test.IntegrationTest do
  use Distillery.Test.IntegrationCase, async: false
  
  @moduletag win32: false

  alias Distillery.Releases.Utils
  import Distillery.Test.Helpers

  describe "standard application" do

    test "can build a release and start it - dev" do
      with_standard_app do
        assert {:ok, output} = build_release(env: :dev, no_tar: true)
        
        # Release plugin was run
        for callback <- ~w(before_assembly after_assembly) do
          assert output =~ "EnvLoggerPlugin in dev executing #{callback}"
        end
        
        bin = Path.join([output_path(), "bin", "standard_app"])
        
        try do
          # Can start
          assert {:ok, _} = release_cmd(bin, "start")
          assert :ok = wait_for_app(bin)
          # Base config is correct
          assert {:ok, "2\n"} =
                   release_cmd(bin, "rpc", ["Application.get_env(:standard_app, :num_procs)"])
          # Config provider was run
          assert {:ok, ":config_provider\n"} =
                   release_cmd(bin, "rpc", ["Application.get_env(:standard_app, :source)"])
          # Can stop
          assert {:ok, _} = release_cmd(bin, "stop")
        rescue
          e ->
            release_cmd(bin, "stop")
            reraise e, System.stacktrace()
        end
      end
    end
    
    test "can build release and start it - prod" do
      with_standard_app do
        assert {:ok, output} = build_release()

        # All release plugins ran
        for callback <- ~w(before_assembly after_assembly before_package after_package) do
          assert output =~ "EnvLoggerPlugin in prod executing #{callback}"
          assert output =~ "ProdPlugin in prod executing #{callback}"
        end
        
        # Extract release to temporary directory
        assert {:ok, tmpdir} = Utils.insecure_mkdir_temp()
        bin = Path.join([tmpdir, "bin", "standard_app"])

        try do
          deploy_tarball(output_path(), "0.0.1", tmpdir)
          # Can start
          assert {:ok, _} = release_cmd(bin, "start")
          assert :ok = wait_for_app(bin)
          # Config provider was run
          assert {:ok, ":config_provider\n"} =
                   release_cmd(bin, "rpc", ["Application.get_env(:standard_app, :source)"])
          # Additional config files were used
          assert {:ok, ":bar\n"} =
                   release_cmd(bin, "rpc", ["Application.get_env(:standard_app, :foo)"])
          # Can stop
          assert {:ok, _} = release_cmd(bin, "stop")
        rescue
          e ->
            release_cmd(bin, "stop")
            reraise e, System.stacktrace()
        after
          File.rm_rf!(tmpdir)
        end
      end
    end

    test "can build and deploy a hot upgrade" do
      with_standard_app do
        assert {:ok, tmpdir} = Utils.insecure_mkdir_temp()
        bin_path = Path.join([tmpdir, "bin", "standard_app"])
        out_path = output_path()

        try do
          # Build v1 release
          assert {:ok, _} = build_release()
          # Apply v2 changes
          v1_to_v2()
          # Build v2 release
          assert {:ok, _} = build_release(upgrade: true)
          # Ensure the versions we expected were produced
          assert ["0.0.2", "0.0.1"] == Utils.get_release_versions(out_path)

          # Unpack and verify
          deploy_tarball(out_path, "0.0.1", tmpdir)
          # Push upgrade release to the staging directory
          deploy_upgrade_tarball(out_path, "0.0.2", tmpdir)

          assert {:ok, _} = release_cmd(bin_path, "start")
          assert :ok = wait_for_app(bin_path)

          # Interact with running release by changing the state of some processes
          assert {:ok, ":ok\n"} = release_cmd(bin_path, "rpc", ["StandardApp.A.push(8)"])
          assert {:ok, ":ok\n"} = release_cmd(bin_path, "rpc", ["StandardApp.B.push(8)"])

          # Install upgrade and verify output
          assert {:ok, output} = release_cmd(bin_path, "upgrade", ["0.0.2"])
          assert output =~ "Made release standard_app:0.0.2 permanent"

          # Verify that the state changes we made were persistent across code changes
          assert {:ok, "{:ok, 8}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.A.pop()"])
          assert {:ok, "{:ok, 8}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.B.pop()"])
          assert {:ok, "{:ok, 2}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.A.version()"])
          assert {:ok, "{:ok, 2}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.B.version()"])

          # Verify that configuration changes took effect
          assert {:ok, "4\n"} =
                   release_cmd(bin_path, "rpc", ["Application.get_env(:standard_app, :num_procs)"])

          assert {:ok, _} = release_cmd(bin_path, "stop")
        rescue
          e ->
            release_cmd(bin_path, "stop")
            reraise e, System.stacktrace()
        after
          File.rm_rf(tmpdir)
          reset_changes!(app_path())
        end
      end
    end

    test "can build and deploy hot upgrade with custom appup" do
      with_standard_app do
        out_path = output_path()
        
        # Build v1 release
        assert {:ok, _} = build_release()
        # Apply v2 changes
        v1_to_v2()
        # Generate appup from old to new version
        assert {:ok, _} = mix("compile")
        assert {:ok, _} = mix("distillery.gen.appup", ["--app=standard_app"])
        # Build v2 release
        assert {:ok, _} = build_release(upgrade: true)
        # Verify versions
        assert ["0.0.2", "0.0.1"] == Utils.get_release_versions(out_path)

        # Deploy it
        assert {:ok, tmpdir} = Utils.insecure_mkdir_temp()
        bin_path = Path.join([tmpdir, "bin", "standard_app"])

        try do
          # Unpack v1 to target directory
          deploy_tarball(out_path, "0.0.1", tmpdir)
          # Push v2 release to staging directory
          deploy_upgrade_tarball(out_path, "0.0.2", tmpdir)

          # Boot v1
          assert {:ok, _} = release_cmd(bin_path, "start")
          assert :ok = wait_for_app(bin_path)

          # Interact with running release by changing state of some processes
          assert {:ok, ":ok\n"} = release_cmd(bin_path, "rpc", ["StandardApp.A.push(8)"])
          assert {:ok, ":ok\n"} = release_cmd(bin_path, "rpc", ["StandardApp.B.push(8)"])

          # Install v2
          assert {:ok, output} = release_cmd(bin_path, "upgrade", ["0.0.2"])
          assert output =~ "Made release standard_app:0.0.2 permanent"

          # Verify that state changes were persistent across code changes
          assert {:ok, "{:ok, 8}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.A.pop()"])
          assert {:ok, "{:ok, 8}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.B.pop()"])
          assert {:ok, "{:ok, 2}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.A.version()"])
          assert {:ok, "{:ok, 2}\n"} = release_cmd(bin_path, "rpc", ["StandardApp.B.version()"])

          # Verify configuration changes took effect
          assert {:ok, "4\n"} =
                   release_cmd(bin_path, "rpc", ["Application.get_env(:standard_app, :num_procs)"])

          assert {:ok, _} = release_cmd(bin_path, "stop")
        rescue
          e ->
            release_cmd(bin_path, "stop")
            reraise e, System.stacktrace()
        after
          File.rm_rf(tmpdir)
          reset_changes!(app_path())
        end
      end
    end

    test "when installation directory contains a space" do
      with_standard_app do
        assert {:ok, _} = build_release()

        # Deploy release to path with spaces
        assert {:ok, tmpdir} = Utils.insecure_mkdir_temp()
        tmpdir = Path.join(tmpdir, "dir with space")
        bin_path = Path.join([tmpdir, "bin", "standard_app"])

        try do
          deploy_tarball(output_path(), "0.0.1", tmpdir)

          # Boot release
          assert {:ok, _} = release_cmd(bin_path, "start")
          assert :ok = wait_for_app(bin_path)

          # Verify configuration
          assert {:ok, "2\n"} =
                   release_cmd(bin_path, "rpc", ["Application.get_env(:standard_app, :num_procs)"])
          assert {:ok, ":bar\n"} =
                   release_cmd(bin_path, "rpc", ["Application.get_env(:standard_app, :foo)"])

          assert {:ok, _} = release_cmd(bin_path, "stop")
        rescue
          e ->
            release_cmd(bin_path, "stop")
            reraise e, System.stacktrace()
        after
          File.rm_rf!(tmpdir)
        end
      end
    end
  end
  
  describe "umbrella application" do
    test "can build umbrella and deploy it - dev" do
      with_umbrella_app do
        assert {:ok, output} = build_release(env: :dev, no_tar: true)
        
        bin = Path.join([output_path(), "bin", "umbrella"])
        
        try do
          # Can start
          assert {:ok, _} = release_cmd(bin, "start")
          assert :ok = wait_for_app(bin)
          # We should be able to execute an HTTP request against the API
          assert :ok = try_healthz()
          # Can stop
          assert {:ok, _} = release_cmd(bin, "stop")
        rescue
          e ->
            release_cmd(bin, "stop")
            reraise e, System.stacktrace()
        end
      end
    end
  end

  defp try_healthz(tries \\ 0) do
    url = 'http://localhost:4000/healthz'
    headers = [{'accepts', 'application/json'}, {'content-type', 'application/json'}]
    opts = [body_format: :binary, full_result: false]
    case :httpc.request(:get, {url, headers}, [], opts) do
      {:ok, {200, _}} -> 
        :ok
      err when tries < 5 ->
        IO.inspect "Request (attempt #{tries} of 5) to /healthz endpoint failed with: #{err}"
        :timer.sleep(1_000)
        try_healthz(tries + 1)
      _ ->
        IO.inspect "Requests to /healthz endpoint exhausted retries"
        :error
    end
  end
end
