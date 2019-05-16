defmodule Distillery.Test.Win32IntegrationTest do
  @moduledoc """
  These are tests for supported Windows functionality.

  Currently this mostly mirrors the other integration tests, except no hot upgrades
  """
  use Distillery.Test.IntegrationCase, async: false
  
  @moduletag win32: true

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
        IO.inspect "Request (attempt #{tries} of 5) to /healthz endpoint failed with: #{err}"
        :error
        end
    end
  end
end
