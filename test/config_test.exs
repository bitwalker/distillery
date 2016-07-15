defmodule ConfigTest do
  use ExUnit.Case, async: true

  alias Mix.Releases.Config
  alias Mix.Releases.Config.ReleaseDefinition

  @standard_app Path.join([__DIR__, "fixtures", "standard_app"])

  describe "standard app" do
    test "can load config" do
      config = Mix.Project.in_project(:standard_app, @standard_app, fn _mixfile ->
        Mix.Releases.Config.read!(Path.join([@standard_app, "rel", "config.exs"]))
      end)
      expected = %Config{releases: [
        %ReleaseDefinition{name: :standard_app, version: "0.0.1", applications: [:elixir, :iex, :sasl, :standard_app]}
      ]}
      assert ^expected = config
    end
  end
end
