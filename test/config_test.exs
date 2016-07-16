defmodule ConfigTest do
  use ExUnit.Case, async: true

  alias Mix.Releases.{Config, Environment, Release, Profile}

  @standard_app Path.join([__DIR__, "fixtures", "standard_app"])

  describe "standard app" do
    test "can load config" do
      config = Mix.Project.in_project(:standard_app, @standard_app, fn _mixfile ->
        Mix.Task.run("compile", [])
        Mix.Releases.Config.read!(Path.join([@standard_app, "rel", "config.exs"]))
      end)
      assert %Config{environments: %{
                        dev: %Environment{profile: %Profile{dev_mode: true, include_erts: false}},
                        default: %Environment{profile: %Profile{dev_mode: false, include_erts: true}}},
                      releases: %{
                        standard_app: %Release{version: "0.0.1", applications: [:elixir, :iex, :sasl, :standard_app]}},
                      default_release: :standard_app,
                      default_environment: :dev,
                     } = config
    end
  end
end
