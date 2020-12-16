defmodule WeChat.Application do
  @moduledoc false

  use Application

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    child_spec = [
      spec_registry(),
      spec_http_client()
    ]

    Supervisor.start_link(child_spec, strategy: :one_for_one)
  end

  def http_name() do
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
    worker(WeChat.Registry, [])
  end

end
