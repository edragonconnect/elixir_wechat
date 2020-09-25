defmodule WeChat.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_wechat,
      version: "0.2.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.3"},
      {:jason, "~> 1.1"},
      {:timex, "~> 3.6"},
      {:hackney, "~> 1.15.2"},
      {:plug, "~> 1.10", optional: true},
      {:mock, "~> 0.3", only: :test},
      {:ex_doc, "~> 0.21", only: [:docs, :dev], runtime: false}
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
        {"BeHaviour",
         [
           WeChat.Storage.Client,
           WeChat.Storage.Hub,
           WeChat.Storage.ComponentClient,
           WeChat.Storage.ComponentHub
         ]},
        {"Meta",
         [
           WeChat.CardSignature,
           WeChat.JSSDKSignature,
           WeChat.Token,
           WeChat.Error
         ]},
        {"Meta Upload",
         [
           WeChat.UploadMedia,
           WeChat.UploadMediaContent
         ]}
      ]
    ]
  end

  defp description() do
    "WeChat SDK for Elixir"
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Xin Zou", "Kevin Pan"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/edragonconnect/elixir_wechat"}
    ]
  end
end
