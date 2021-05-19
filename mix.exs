defmodule GenesisPubSub.MixProject do
  use Mix.Project

  def project() do
    [
      app: :genesis_pubsub,
      version: "0.11.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "PubSub",
      source_url: "https://github.com/genesisblockhq/pubsub",
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
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
  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  # We use a custom broadway_cloud_pub_sub because of:
  #   https://github.com/dashbitco/broadway_cloud_pub_sub/issues/55
  defp deps() do
    [
      {:broadway_cloud_pub_sub, "~> 0.6.5", organization: "genesisblock"},
      {:broadway, "~> 0.6.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:genesis_credo, "~> 1.0.0", only: [:dev, :test], runtime: false, organization: "genesisblock"},
      {:goth, "~> 1.2.0"},
      {:hammox, "~> 0.3", only: [:test]},
      {:jason, "~> 1.2"},
      {:protobuf, "~> 0.7.1", only: [:test, :dev]},
      {:tesla, "~> 1.3"},
      {:uuid, "~> 1.1"}
    ]
  end

  defp aliases() do
    [
      credo: ["credo --config-file deps/genesis_credo/.credo.exs"]
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
          GenesisPubSub.Adapter.GoogleLocal
        ]
      ]
    ]
  end
end
