defmodule Distillery.Test.IntegrationTest do
  use ExUnit.Case, async: false

  alias Mix.Releases.Utils
  import Distillery.Test.Helpers

  @moduletag integration: true
  @moduletag timeout: 60_000 * 5

  @standard_app_path Path.join([__DIR__, "fixtures", "standard_app"])
  @standard_build_path Path.join([@standard_app_path, "_build", "prod"])
  @standard_output_path Path.join([@standard_build_path, "rel", "standard_app"])

  defmacrop with_standard_app(body) do
    quote do
      old_dir = File.cwd!()
      File.cd!(@standard_app_path)
      try do
        unquote(body)
      after
        File.cd!(old_dir)
      end
    end
  end
  
  setup_all do
    with_standard_app do
      {:ok, _} = File.rm_rf(Path.join(@standard_app_path, "_build"))
      _ = File.rm(Path.join(@standard_app_path, "mix.lock"))
      {:ok, _} = mix("deps.get")
      {:ok, _} = mix("compile")
    end
    :ok
  end
  
  setup do
    with_standard_app do
      reset_changes!(@standard_app_path)
    end
    :ok
  end

  describe "standard application" do

    test "can build a release and start it - dev" do
      with_standard_app do
        assert {:ok, output} = build_release(env: :dev, no_tar: true)
        
        # Release plugin was run
        for callback <- ~w(before_assembly after_assembly) do
          assert output =~ "EnvLoggerPlugin in dev executing #{callback}"
        end
        
        bin = Path.join([@standard_output_path, "bin", "standard_app"])
        
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
          deploy_tarball(@standard_output_path, "0.0.1", tmpdir)
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

        try do
          # Build v1 release
          assert {:ok, _} = build_release()
          # Apply v2 changes
          v1_to_v2()
          # Build v2 release
          assert {:ok, _} = build_release(upgrade: true)
          # Ensure the versions we expected were produced
          assert ["0.0.2", "0.0.1"] == Utils.get_release_versions(@standard_output_path)

          # Unpack and verify
          deploy_tarball(@standard_output_path, "0.0.1", tmpdir)
          # Push upgrade release to the staging directory
          deploy_upgrade_tarball(@standard_output_path, "0.0.2", tmpdir)

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
          reset_changes!(@standard_app_path)
        end
      end
    end

    test "can build and deploy hot upgrade with custom appup" do
      with_standard_app do
        # Build v1 release
        assert {:ok, _} = build_release()
        # Apply v2 changes
        v1_to_v2()
        # Generate appup from old to new version
        assert {:ok, _} = mix("compile")
        assert {:ok, _} = mix("release.gen.appup", ["--app=standard_app"])
        # Build v2 release
        assert {:ok, _} = build_release(upgrade: true)
        # Verify versions
        assert ["0.0.2", "0.0.1"] == Utils.get_release_versions(@standard_output_path)

        # Deploy it
        assert {:ok, tmpdir} = Utils.insecure_mkdir_temp()
        bin_path = Path.join([tmpdir, "bin", "standard_app"])

        try do
          # Unpack v1 to target directory
          deploy_tarball(@standard_output_path, "0.0.1", tmpdir)
          # Push v2 release to staging directory
          deploy_upgrade_tarball(@standard_output_path, "0.0.2", tmpdir)

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
          reset_changes!(@standard_app_path)
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
          deploy_tarball(@standard_output_path, "0.0.1", tmpdir)

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
  
  defp v1_to_v2 do
    config_path = Path.join([@standard_app_path, "config", "config.exs"])
    a_path = Path.join([@standard_app_path, "lib", "standard_app", "a.ex"])
    b_path = Path.join([@standard_app_path, "lib", "standard_app", "b.ex"])

    upgrade(@standard_app_path, "0.0.2", [
      {config_path, "num_procs: 2", "num_procs: 4"},
      {a_path, "{:ok, {1, []}}", "{:ok, {2, []}}"},
      {b_path, "loop({1, []}, parent, debug)", "loop({2, []}, parent, debug)"}
    ])
  end
  
  defp reset!(path) do
    backup = path <> ".backup"
    if File.exists?(backup) do
      File.cp!(backup, path)
      File.rm!(backup)
    end
  end
  
  defp reset_changes!(app_path) do
    app = Path.basename(app_path)
    changes =
      Path.join([app_path, "**", "*.backup"])
      |> Path.wildcard()
      |> Enum.map(&(Path.join(Path.dirname(&1), Path.basename(&1, ".backup"))))
    Enum.each(changes, &reset!/1)
    File.rm_rf!(Path.join([app_path, "rel", app]))
    File.rm_rf!(Path.join([app_path, "rel", "appups", app]))
    :ok
  end
  
  defp apply_change(path, match, replacement) do
    apply_changes(path, [{match, replacement}])
  end
  
  defp apply_changes(path, changes) when is_list(changes) do
    unless File.exists?(path <> ".backup") do
      File.cp!(path, path <> ".backup")
    end
    old = File.read!(path)
    new = 
      changes
      |> Enum.reduce(old, fn {match, replacement}, acc -> 
        String.replace(acc, match, replacement)
      end)
    File.write!(path, new)
  end
  
  defp upgrade(app_path, version, changes) do
    # Set new version in mix.exs
    mix_exs = Path.join([app_path, "mix.exs"])
    apply_change(mix_exs, ~r/(version: )"\d+.\d+.\d+"/, "\\1\"#{version}\"")
    # Set new version in release config
    rel_config_path = Path.join([app_path, "rel", "config.exs"])
    apply_change(rel_config_path, ~r/(version: )"\d+.\d+.\d+"/, "\\1\"#{version}\"")
    # Apply other changes for this upgrade
    for change <- changes do
      case change do
        {path, changeset} when is_list(changeset) ->
          apply_changes(path, changeset)
        {path, match, replacement} ->
          apply_change(path, match, replacement)
      end
    end
    :ok
  end
  
  defp deploy_tarball(release_root_dir, version, directory) do
    dir = String.to_charlist(directory)
    tar = 
      case Path.wildcard(Path.join([release_root_dir, "releases", version, "*.tar.gz"])) do
        [tar] ->
          String.to_charlist(tar)
      end
    case :erl_tar.extract(tar, [{:cwd, dir}, :compressed]) do
      :ok ->
        :ok = Utils.write_term(Path.join(directory, "extra.config"), standard_app: [foo: :bar])
      other ->
        other
    end
  end
  
  defp deploy_upgrade_tarball(release_root_dir, version, directory) do
    target = Path.join([directory, "releases", version])
    File.mkdir_p!(Path.join([directory, "releases", version]))
    source = 
      case Path.wildcard(Path.join([release_root_dir, "releases", version, "*.tar.gz"])) do
        [source] ->
          source
      end
    name = Path.basename(source)
    File.cp!(source, Path.join(target, name))
  end
end
