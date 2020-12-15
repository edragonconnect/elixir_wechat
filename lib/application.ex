defmodule WeChat.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    child_spec = [
      {Registry, keys: :unique, name: WeChat.Registry}
    ]

    Supervisor.start_link(child_spec, strategy: :one_for_one)
  end

end
