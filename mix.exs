defmodule WeChat.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_wechat,
      version: "0.1.3",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:docs), do: ["lib", "priv/guide"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19", only: [:docs, :dev], runtime: false},
      {:toml, "~> 0.3"},
      {:tesla, "~> 1.2"},
      {:jason, "~> 1.1"},
      {:timex, "~> 3.5"},
      {:mock, "~> 0.3", only: :test},
    ]
  end

  defp docs do
    [
      main: "readme",
      formatter_opts: [gfm: true],
      extras: [
        "README.md"
      ],
      groups_for_modules: [
        BeHaviour: [
          WeChat.Adapter.Storage.Client,
          WeChat.Adapter.Storage.ComponentClient,
          WeChat.Adapter.Storage.Hub,
          WeChat.Adapter.Storage.ComponentHub,
        ],
        "Guide - Common": [
          DynamicAppIdClient,
          DynamicAppIdHubClient,
          GlobalAppIdClient,
          GlobalAppIdHubClient,
        ],
        "Guide - Component": [
          DynamicComponentAppIdClient,
          DynamicComponentAppIdHubClient,
          GlobalComponentAppIdClient,
          GlobalComponentAppIdHubClient
        ],
        Upload: [
          WeChat.UploadMedia,
          WeChat.UploadMediaContent
        ]
      ]
    ]
  end

  defp description() do
    "WeChat SDK for Elixir"
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md", "config/*.toml"],
      maintainers: ["Xin Zou"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/edragonconnect/elixir_wechat"}
    ]
  end
end
