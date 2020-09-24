if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.Router do
    use Plug.Router

    alias WeChat.Plug.{FetchAccessToken, RefreshAccessToken, FetchComponentAccessToken}

    alias WeChat.Url

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

    get Url.to_fetch_ticket() do
      Plug.run(conn, [{FetchTicket, opts}])
    end

    match _ do
      conn
    end
  end
end
