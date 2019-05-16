defmodule Distillery.Test.InitTest do
  use ExUnit.Case

  import Distillery.Test.Helpers

  @fixtures_path Path.join([__DIR__, "..", "fixtures"])
  @init_test_app_path Path.join([@fixtures_path, "init_test_app"])
  @init_test_rel_path Path.join([@fixtures_path, "init_test_app", "rel"])
  @init_test_rel_config_path Path.join([@fixtures_path, "init_test_app", "rel", "config.exs"])
  @init_test_invalid_config_template_path Path.join([
                                            @fixtures_path,
                                            "init_test_app",
                                            "init_test_config.eex"
                                          ])

  @init_test_rel_vm_args_path Path.join([@fixtures_path, "init_test_app", "rel", "vm.args"])

  setup_all do
    old_dir = File.cwd!()
    File.cd!(@init_test_app_path)
    {:ok, _} = mix("deps.get")
    File.cd!(old_dir)
  end

  setup do
    File.rm_rf(@init_test_rel_path)

    on_exit(fn ->
      File.rm_rf(@init_test_rel_path)
    end)
  end

  describe "distillery.init" do
    test "creates an example rel/config.exs" do
      old_dir = File.cwd!()
      File.cd!(@init_test_app_path)

      try do
        refute File.exists?(@init_test_rel_path)
        refute File.exists?(@init_test_rel_config_path)
        assert {:ok, _} = mix("distillery.init")
        assert File.exists?(@init_test_rel_path)
        assert File.exists?(@init_test_rel_config_path)
        # It would be nice to test that Distillery.Releases.Config.read! succeeds here
        # to verify that the example config is valid, but the call to current_version
        # in the example config fails because the init_test_app has not been loaded
        # in this test context.
      after
        File.cd!(old_dir)
      end
    end

    test "creates rel/config.exs from a custom template" do
      old_dir = File.cwd!()
      File.cd!(@init_test_app_path)

      try do
        refute File.exists?(@init_test_rel_path)
        refute File.exists?(@init_test_rel_config_path)

        assert {:ok, _} =
                 mix("distillery.init", ["--template=#{@init_test_invalid_config_template_path}"])

        assert File.exists?(@init_test_rel_path)
        assert File.exists?(@init_test_rel_config_path)
      after
        File.cd!(old_dir)
      end
    end

    test "creates an example rel/vm.args" do
      old_dir = File.cwd!()
      File.cd!(@init_test_app_path)

      try do
        refute File.exists?(@init_test_rel_path)
        refute File.exists?(@init_test_rel_vm_args_path)
        assert {:ok, _} = mix("distillery.init")
        assert File.exists?(@init_test_rel_path)
        assert File.exists?(@init_test_rel_vm_args_path)
        # It would be nice to test that Distillery.Releases.Config.read! succeeds here
        # to verify that the example config is valid, but the call to current_version
        # in the example config fails because the init_test_app has not been loaded
        # in this test context.
      after
        File.cd!(old_dir)
      end
    end

    test "creates rel/vm.args from a custom template" do
      old_dir = File.cwd!()
      File.cd!(@init_test_app_path)

      try do
        refute File.exists?(@init_test_rel_path)
        refute File.exists?(@init_test_rel_vm_args_path)

        assert {:ok, _} =
                 mix("distillery.init", ["--template=#{@init_test_invalid_config_template_path}"])

        assert File.exists?(@init_test_rel_path)
        assert File.exists?(@init_test_rel_vm_args_path)
      after
        File.cd!(old_dir)
      end
    end
  end
end
