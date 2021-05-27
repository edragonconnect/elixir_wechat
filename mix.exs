defmodule WeChat.MixProject do
  use Mix.Project

  @source_url "https://github.com/edragonconnect/elixir_wechat"

  def project do
    [
      app: :elixir_wechat,
      version: "0.4.3",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {WeChat.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:finch, "~> 0.5"},
      {:jason, "~> 1.1"},
      {:timex, "~> 3.6"},
      {:decorator, "~> 1.3"},
      {:plug, "~> 1.10", optional: true},
      {:mock, "~> 0.3", only: :test},
      {:ex_doc, "~> 0.21", only: [:docs, :dev], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      formatter_opts: [gfm: true],
      extras: [
        "README.md"
      ],
      groups_for_modules: [
        {
          "BeHaviour",
          [
            WeChat.Storage.Client,
            WeChat.Storage.Hub,
            WeChat.Storage.ComponentClient,
            WeChat.Storage.ComponentHub
          ]
        },
        {
          "Default Storage Client to Hub",
          [
            WeChat.Storage.Adapter.DefaultClient,
            WeChat.Storage.Adapter.DefaultComponentClient
          ]
        },
        {
          "Meta",
          [
            WeChat.CardSignature,
            WeChat.JSSDKSignature,
            WeChat.Token,
            WeChat.Error
          ]
        },
        {
          "Meta Upload",
          [
            WeChat.UploadMedia,
            WeChat.UploadMediaContent
          ]
        }
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
      links: %{"GitHub" => @source_url}
    ]
  end
end
