defmodule GenesisPubSub.MixProject do
  use Mix.Project

  def project do
    [
      app: :genesis_pubsub,
      version: "0.7.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "PubSub",
      source_url: "https://github.com/genesisblockhq/pubsub",
      docs: docs(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      test_paths: ["lib"],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit],
        flags: [:error_handling, :race_conditions, :unmatched_returns, :underspecs],
        list_unused_filters: true,
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:broadway_cloud_pub_sub, "~> 0.6.0"},
      {:broadway, "~> 0.6.0"},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:hammox, "~> 0.3", only: [:test]},
      {:jason, "~> 1.2"},
      {:tesla, "~> 1.3"},
      {:uuid, "~> 1.1"},
      {:protobuf, "~> 0.7.1", only: [:test, :dev]},
      {:telemetry, "~> 0.4"}
    ]
  end

  defp package() do
    [
      organization: "genesisblock",
      files: ["lib", "mix.exs", "README*"]
    ]
  end

  def docs() do
    [
      main: "GenesisPubSub",
      extra_section: "GUIDES",
      extras: ["guides/testing.md", "guides/telemetry.md"],
      groups_for_modules: [
        Adapters: [
          GenesisPubSub.Adapter,
          GenesisPubSub.Adapter.Google,
          GenesisPubSub.Adapter.Local
        ]
      ]
    ]
  end
end
