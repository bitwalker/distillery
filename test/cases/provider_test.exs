defmodule Distillery.Test.ProviderTest do
  use ExUnit.Case
  
  alias Distillery.Releases.Config.Providers
  
  @fixtures_path Path.join([__DIR__, "..", "fixtures"])
  @umbrella_config_path Path.join([@fixtures_path, "umbrella_app", "config", "config.exs"])
  @web_config_path Path.join([@fixtures_path, "umbrella_app", "apps", "web", "config", "config.exs"])
  
  describe "with umbrella app" do
    test "can read config with expected results" do
      config = Providers.Elixir.eval!(@umbrella_config_path)
      assert Web = get_in(config, [:web, :namespace])
    end
  end
  
  describe "with standard app" do
    test "can read config with expected results" do
      config = Providers.Elixir.eval!(@web_config_path)
      assert Web = get_in(config, [:web, :namespace])
    end
  end
end
