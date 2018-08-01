defmodule ProviderTest do
  use ExUnit.Case
  
  alias Mix.Releases.Config.Providers
  
  @umbrella_config_path Path.join([__DIR__, "fixtures", "umbrella_test", "config", "config.exs"])
  @app1_config_path Path.join([__DIR__, "fixtures", "umbrella_test", "apps", "app1", "config", "config.exs"])
  
  describe "with umbrella app" do
    test "can read config with expected results" do
      config = Providers.Elixir.eval!(@umbrella_config_path)
      assert :baz = get_in(config, [:app1, :foo])
      assert :quz = get_in(config, [:app2, :foo])
    end
  end
  
  describe "with standard app" do
    test "can read config with expected results" do
      config = Providers.Elixir.eval!(@app1_config_path)
      assert :baz = get_in(config, [:app1, :foo])
    end
  end
end
