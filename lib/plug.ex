if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug do
    @behaviour Plug

    @impl true
    def init(opts) do
      opts
    end

    @impl true
    def call(conn, _opts) do
      conn
    end
  end
end
