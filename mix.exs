defmodule Bundler.Mixfile do
  use Mix.Project

  def project do
    [app: :bundler,
     version: "0.2.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     description: description,
     package: package,
     docs: docs]
  end

  def application, do: [applications: []]

  defp deps do
    [{:ex_doc, github: "elixir-lang/ex_doc", only: [:dev]},
     {:earmark, "~> 1.0", only: [:dev]},
     {:excoveralls, "~> 0.5", only: [:dev, :test]}]
  end

  defp description do
    """
    Build releases of your Mix projects with ease!
    WARNING: This package is an experimental replacement for exrm, use at your own risk!
    """
  end
  defp package do
    [ files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{"Github": "https://github.com/bitwalker/bundler",
               "Documentation": "https://hexdocs.pm/bundler"}]
  end
  defp docs do
    [main: "getting-started",
     extras: [
       "docs/Getting Started.md",
       "docs/Configuration.md",
       "docs/Walkthrough.md",
       "docs/Upgrades and Downgrades.md",
       "docs/Common Issues.md"
     ]]
  end
end
