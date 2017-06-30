defmodule Distillery.Mixfile do
  use Mix.Project

  def project do
    [app: :distillery,
     version: "1.4.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),
     docs: docs(),
     aliases: aliases(),
     test_coverage: [tool: ExCoveralls]]
  end

  def application, do: [applications: []]

  defp deps do
    [{:ex_doc, "~> 0.13", only: [:dev]},
     {:excoveralls, "~> 0.6", only: [:dev, :test]},
     {:credo, "~> 0.6", only: [:dev]},
     {:propcheck, "~> 0.0.1", only: :test},
     {:dialyze, "~> 0.2", only: [:dev]}]
  end

  defp description do
    """
    Build releases of your Mix projects with ease!
    """
  end
  defp package do
    [files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md"],
     maintainers: ["Paul Schoenfelder"],
     licenses: ["MIT"],
     links: %{"Github": "https://github.com/bitwalker/distillery"}]
  end
  defp aliases do
    ["compile-check": "do compile, credo --strict"]
  end
  defp docs do
    [main: "getting-started",
     extras: [
       "docs/Getting Started.md",
       "docs/CLI.md",
       "docs/Configuration.md",
       "docs/Runtime Configuration.md",
       "docs/Walkthrough.md",
       "docs/Use With Phoenix.md",
       "docs/Phoenix Walkthrough.md",
       "docs/Running Migrations.md",
       "docs/Upgrades and Downgrades.md",
       "docs/Use With systemd.md",
       "docs/Common Issues.md",
       "docs/Umbrella Projects.md",
       "docs/Overlays.md",
       "docs/Plugins.md",
       "docs/Boot Hooks.md",
       "docs/Custom Commands.md",
       "docs/Shell Script API.md",
       "docs/Terminology.md"
     ]]
  end
end
