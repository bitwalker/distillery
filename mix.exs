defmodule Distillery.Mixfile do
  use Mix.Project

  def project do
    [
      app: :distillery,
      version: "2.0.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        flags: ["-Wunmatched_returns", :error_handling, :race_conditions, :underspecs]
      ]
    ]
  end

  def application do
    [extra_applications: [:runtime_tools]]
  end

  defp deps do
    [
      {:artificery, "~> 0.2"},
      {:ex_doc, "~> 0.13", only: [:dev]},
      {:excoveralls, "~> 0.6", only: [:dev, :test]},
      {:credo, "~> 0.6", only: [:dev]},
      {:eqc_ex, "~> 1.4", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0-rc.2", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Build releases of your Mix projects with ease!
    """
  end

  defp package do
    [
      files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{Github: "https://github.com/bitwalker/distillery"}
    ]
  end

  defp aliases do
    ["compile-check": "do compile, credo --strict"]
  end

  defp docs do
    [
      main: "overview",
      extra_section: "GUIDES",
      groups_for_extras: [
        "Introduction": ~r/docs\/introduction\/.?/,
        "Guides": ~r/docs\/guides\/.?/,
        "Deployment": ~r/docs\/deployment\/.?/,
        "Files": ~r/docs\/files\/.?/,
        "Plugins": ~r/docs\/plugins\/.?/,
        "Overlays": ~r/docs\/overlays\/.?/,
        "Other": ~r/docs\/[^\.]+.md/
      ],
      extras: [
        "docs/introduction/overview.md",
        "docs/introduction/up_and_running.md",
        "docs/introduction/understanding_releases.md",
        "docs/introduction/walkthrough.md",
        "docs/introduction/release_configuration.md",
        "docs/introduction/umbrella_projects.md",
        "docs/introduction/terminology.md",
        "docs/guides/phoenix_walkthrough.md",
        "docs/guides/running_migrations.md",
        "docs/guides/upgrades_and_downgrades.md",
        "docs/guides/appups.md",
        "docs/guides/systemd.md",
        "docs/guides/configuration.md",
        "docs/overlays/overlays.md",
        "docs/plugins/release_plugins.md",
        "docs/plugins/config_providers.md",
        "docs/plugins/custom_commands.md",
        "docs/plugins/boot_hooks.md",
        "docs/files/vm.args.md",
        "docs/faq.md",
        "docs/cli.md",
        "docs/shell_scripts.md",
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
