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
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.13", only: [:dev]},
      {:excoveralls, "~> 0.6", only: [:dev, :test]},
      {:credo, "~> 0.6", only: [:dev]},
      {:eqc_ex, "~> 1.4", only: [:dev, :test]},
      {:dialyze, "~> 0.2", only: [:dev]}
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
        "docs/guides/phoenix_walkthrough.md",
        "docs/guides/running_migrations.md",
        "docs/guides/upgrades_and_downgrades.md",
        "docs/guides/systemd.md",
        "docs/guides/configuration.md",
        "docs/overlays/overlays.md",
        "docs/plugins/release_plugins.md",
        "docs/plugins/config_providers.md",
        "docs/files/vm.args.md",
        "docs/cli.md",
        "docs/common_issues.md",
        "docs/umbrella_projects.md",
        "docs/boot_hooks.md",
        "docs/custom_commands.md",
        "docs/shell_scripts.md",
        "docs/terminology.md",
      ]
    ]
  end
end
