if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.Pipeline do
    use Plug.Builder
    require Logger
    
    plug WeChat.Plug.Router, builder_opts()
    plug :verify_access_token, builder_opts()

    defp verify_access_token(conn, opts) do
      #Logger.info "verify_access_token conn: #{inspect(conn)}" 
      Logger.info "opts: #{inspect(opts)}"
      conn
    end

  end
end
