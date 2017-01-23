defmodule ConfigTest do
  use ExUnit.Case

  alias Mix.Releases.{Config, Environment, Release, Profile}

  @standard_app Path.join([__DIR__, "fixtures", "standard_app"])

  describe "standard app" do
    test "read!" do
      config = Mix.Project.in_project(:standard_app, @standard_app, fn _mixfile ->
        Mix.Releases.Config.read!(Path.join([@standard_app, "rel", "config.exs"]))
      end)
      assert %Config{environments: %{
                        dev: %Environment{profile: %Profile{dev_mode: true, include_erts: false}},
                        prod: %Environment{profile: %Profile{dev_mode: false, include_erts: true, strip_debug_info: false}}},
                      releases: %{
                        standard_app: %Release{version: "0.0.1", applications: [:elixir, :iex, :sasl]}},
                      default_release: :default,
                      default_environment: :dev,
                     } = config
    end

    test "read_string!" do
      config = """
      use Mix.Releases.Config

      release :distillery do
        set version: current_version(:distillery)
      end
      """ |> Mix.Releases.Config.read_string!
      distillery_ver = Keyword.fetch!(Mix.Project.config, :version)
      assert %Config{environments: %{
                        default: %Environment{}
                     },
                     releases: %{
                       distillery: %Release{version: ^distillery_ver}
                     },
                     default_release: :default, default_environment: :default} = config
    end
  end

  describe "plugin config" do
    test "read!" do
      config = Mix.Project.in_project(:standard_app, @standard_app, fn _mixfile ->
        Mix.Releases.Config.read!(Path.join([@standard_app, "rel", "config.exs"]))
      end)
      prod_plugin = [{SampleApp.ProdPlugin, [some: :config]}]
      rel_plugin = [{SampleApp.ReleasePlugin, []}]
      assert %Config{environments: %{
                        dev: %Environment{profile: %Profile{plugins: []}},
                        prod: %Environment{profile: %Profile{plugins: ^prod_plugin}}},
                     releases: %{
                       standard_app: %Release{profile: %Profile{plugins: ^rel_plugin}}}
      } = config
    end
  end
end
