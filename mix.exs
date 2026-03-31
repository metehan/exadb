defmodule Exadb.MixProject do
  use Mix.Project

  def project do
    [
      app: :exadb,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      name: "Exadb",
      source_url: "https://github.com/metehan/exadb",
      homepage_url: "https://github.com/metehan/exadb"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.8"},
      {:poison, "~> 5.0"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Lightweight ArangoDB client helpers for documents, queries, collections, graphs, users, and database management."
  end

  defp package do
    [
      files: ~w(lib guides .formatter.exs mix.exs README.md CHANGELOG.md),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/metehan/exadb",
        "ArangoDB HTTP API" => "https://docs.arango.ai/arangodb/stable/develop/http-api/"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/document-workflow.md",
        "guides/queries-and-cursors.md",
        "guides/schema-and-operations.md",
        "guides/testing.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        Core: [Exadb, Exadb.Api, Exadb.Http, Exadb.Tools],
        Data: [Exadb.Doc, Exadb.Query, Exadb.Collection, Exadb.Index, Exadb.Graph],
        Admin: [Exadb.Database, Exadb.User, Exadb.Manager]
      ]
    ]
  end
end
