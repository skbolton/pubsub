defmodule PubSub.MixProject do
  use Mix.Project

  def project() do
    [
      app: :genesis_pubsub,
      version: "0.13.8",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "PubSub",
      source_url: "https://github.com/skbolton/pubsub",
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      test_paths: ["lib"],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit],
        flags: [:error_handling, :unmatched_returns, :underspecs],
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
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  # We use a custom broadway_cloud_pub_sub because of:
  #   https://github.com/dashbitco/broadway_cloud_pub_sub/issues/55
  defp deps() do
    [
      {:broadway_cloud_pub_sub, "~> 0.7"},
      {:broadway, "~> 1.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:google_api_pub_sub, "~> 0.36"},
      {:goth, "~> 1.3.0"},
      {:hammox, "~> 0.3", only: [:test]},
      {:jason, "~> 1.2"},
      {:protobuf, "~> 0.9", only: [:test, :dev]},
      {:tesla, "~> 1.3"},
      {:uuid, "~> 1.1"}
    ]
  end

  defp package() do
    [
      files: ["lib", "mix.exs", "README*"]
    ]
  end

  def docs() do
    [
      main: "PubSub",
      extra_section: "GUIDES",
      extras: ["guides/testing.md", "guides/telemetry.md"],
      groups_for_modules: [
        Adapters: [
          PubSub.Adapter,
          PubSub.Adapter.Google,
          PubSub.Adapter.GoogleLocal
        ]
      ]
    ]
  end
end
