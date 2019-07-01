defmodule Distillery.Mixfile do
  use Mix.Project

  def project do
    [
      app: :distillery,
      version: "2.1.1",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env),
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs,
        "eqc.install": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
      ],
      test_coverage: [tool: ExCoveralls],
      test_paths: ["test/cases"],
      dialyzer_warnings: [
        :error_handling,
        :race_conditions,
        :underspecs,
        :unknown
      ],
      dialyzer_ignored_warnings: [
        {:warn_contract_supertype, :_, {:contract_supertype, [:_, :impl_for, 1, :_, :_]}},
        {:warn_contract_supertype, :_, {:contract_supertype, [:_, :impl_for!, 1, :_, :_]}}
      ]
    ]
  end

  def application do
    [extra_applications: [:runtime_tools]]
  end

  defp deps do
    [
      {:artificery, "~> 0.2"},
      {:ex_doc, "~> 0.13", only: [:docs]},
      {:excoveralls, "~> 0.6", only: [:test]},
      {:eqc_ex, "~> 1.4", only: [:test]},
      {:ex_unit_clustered_case, "~> 0.3", only: [:test], runtime: false},
      {:dialyzex, "~> 1.2", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Build releases of your Mix projects with ease!
    """
  end

  defp package do
    [
      files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md", ".formatter.exs"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{
        Documentation: "https://hexdocs.pm/distillery",
        Changelog: "https://hexdocs.pm/distillery/changelog.html",
        GitHub: "https://github.com/bitwalker/distillery"
      }
    ]
  end

  defp aliases do
    [
      docs: [&mkdocs/1, "docs"],
      c: ["compile", "format --check-equivalent"],
      "compile-check": [
        "compile",
        "format --check-formatted --dry-run",
        "dialyzer"
      ],
    ]
  end

  defp mkdocs(_args) do
    docs = Path.join([File.cwd!, "bin", "docs"])
    {_, 0} = System.cmd(docs, ["build"], into: IO.stream(:stdio, :line))
  end

  defp docs do
    [
      source_url: "https://github.com/bitwalker/distillery",
      homepage_url: "https://github.com/bitwalker/distillery",
      main: "home"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
