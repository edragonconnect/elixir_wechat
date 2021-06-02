defmodule WeChat.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    child_spec = [
      spec_registry(),
      spec_http_client()
    ]

    Supervisor.start_link(child_spec, strategy: :one_for_one)
  end

  def http_adapter(opts \\ []) do
    opts =
      opts
      |> Keyword.put(:name, http_name())
      |> Keyword.put_new(:receive_timeout, 15_000)

    {
      Tesla.Adapter.Finch,
      opts
    }
  end

  defp http_name() do
    __MODULE__.Finch
  end

  defp spec_http_client() do
    app = Application.get_application(__MODULE__)
    {
      Finch,
      pools: %{
        :default => [
          size: Application.get_env(app, :pool_size, 100),
          count: Application.get_env(app, :pool_count, 1)
        ]
      },
      name: http_name()
    }
  end

  defp spec_registry() do
    WeChat.Registry
  end

end
