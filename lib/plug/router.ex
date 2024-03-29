if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.Router do
    @moduledoc false

    use Plug.Router
    alias WeChat.Url

    alias WeChat.Plug.{
      FetchAccessToken,
      RefreshAccessToken,
      FetchComponentAccessToken,
      RefreshComponentAccessToken,
      FetchTicket
    }

    plug(:match)
    plug(:dispatch, builder_opts())

    get Url.to_fetch_access_token() do
      Plug.run(conn, [{FetchAccessToken, opts}])
    end

    post Url.to_refresh_access_token() do
      Plug.run(conn, [{RefreshAccessToken, opts}])
    end

    get Url.to_fetch_component_access_token() do
      Plug.run(conn, [{FetchComponentAccessToken, opts}])
    end

    post Url.to_refresh_component_access_token() do
      Plug.run(conn, [{RefreshComponentAccessToken, opts}])
    end

    get Url.to_fetch_ticket() do
      Plug.run(conn, [{FetchTicket, opts}])
    end

    match _ do
      conn
    end
  end
end
