defmodule Distillery.Test.ConfigTest do
  use ExUnit.Case

  alias Distillery.Releases.{Config, Environment, Release, Profile}

  @fixtures_path Path.join([__DIR__, "..", "fixtures"])
  @standard_app Path.join([@fixtures_path, "standard_app"])

  describe "standard app" do
    test "read!" do
      config =
        Mix.Project.in_project(:standard_app, @standard_app, fn _mixfile ->
          Distillery.Releases.Config.read!(Path.join([@standard_app, "rel", "config.exs"]))
        end)

      assert %Config{
               environments: %{
                 dev: %Environment{profile: %Profile{dev_mode: true, include_erts: false}},
                 prod: %Environment{
                   profile: %Profile{dev_mode: false, include_erts: true, strip_debug_info: false}
                 }
               },
               releases: %{
                 standard_app: %Release{
                   version: "0.0.1",
                   applications: [
                     :elixir,
                     :iex,
                     :mix,
                     :sasl,
                     :runtime_tools,
                     :distillery,
                   ]
                 }
               },
               default_release: :default,
               default_environment: :dev
             } = config
    end

    test "read_string!" do
      config =
        """
        use Distillery.Releases.Config

        release :distillery do
          set version: current_version(:distillery)
        end
        """
        |> Distillery.Releases.Config.read_string!()

      distillery_ver = Keyword.fetch!(Mix.Project.config(), :version)

      assert %Config{
               environments: %{
                 default: %Environment{}
               },
               releases: %{
                 distillery: %Release{version: ^distillery_ver}
               },
               default_release: :default,
               default_environment: :default
             } = config
    end
  end

  describe "plugin config" do
    test "read!" do
      config =
        Mix.Project.in_project(:standard_app, @standard_app, fn _mixfile ->
          Distillery.Releases.Config.read!(Path.join([@standard_app, "rel", "config.exs"]))
        end)

      rel_plugins = [
        {SampleApp.EnvLoggerPlugin, []},
      ]
      prod_plugins = [
        {SampleApp.EnvLoggerPlugin, [name: ProdPlugin]}
      ]

      assert %Config{
        environments: %{
          dev: %Environment{profile: %Profile{plugins: []}},
          prod: %Environment{profile: %Profile{plugins: ^prod_plugins}}
        },
        releases: %{
          standard_app: %Release{profile: %Profile{plugins: ^rel_plugins}}
        }
      } = config
    end
  end
end
