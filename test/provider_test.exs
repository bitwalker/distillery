defmodule ProviderTest do
  use ExUnit.Case
  
  alias Mix.Releases.Config.Providers
  
  @umbrella_config_path Path.join([__DIR__, "fixtures", "umbrella_test", "config", "config.exs"])
  @app1_config_path Path.join([__DIR__, "fixtures", "umbrella_test", "apps", "app1", "config", "config.exs"])
  
  # Dirty, dirty hack to get the to-be-persisted config
  @extra {{:., [line: 1], [{:__aliases__, [line: 1], [:Mix, :Config, :Agent]}, :get]},
           [line: 1], [{:config_agent, [line: 1], Mix.Config}]}
  
  describe "with umbrella app" do
    test "can read config with expected results" do
      {:__block__, _, quoted} = Providers.Elixir.read_quoted!(@umbrella_config_path)
      quoted = {:__block__, [], quoted ++ [@extra]}
      {config, _} = Code.eval_quoted(quoted)
      assert :baz = get_in(config, [:app1, :foo])
      assert :quz = get_in(config, [:app2, :foo])
    end
  end
  
  describe "with standard app" do
    test "can read config with expected results" do
      {:__block__, _, quoted} = Providers.Elixir.read_quoted!(@app1_config_path)
      quoted = {:__block__, [], quoted ++ [@extra]}
      {config, _} = Code.eval_quoted(quoted)
      assert :baz = get_in(config, [:app1, :foo])
    end
  end
end
