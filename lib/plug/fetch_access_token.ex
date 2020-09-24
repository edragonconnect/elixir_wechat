if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.FetchAccessToken do
    @moduledoc false

    use Plug.Builder

    require Logger

    def call(conn, opts) do
      conn = fetch_query_params(conn)
      adapter_storage = opts[:adapter_storage]
      query_params = conn.query_params

      result =
        try do
          case fetch(query_params, adapter_storage) do
            {:ok, token} ->
              %{"access_token" => token.access_token}

            {:error, %WeChat.Error{} = error} ->
              Logger.error(
                "fetch access token occurs an error: #{inspect(error)} with query params: #{
                  inspect(query_params)
                }"
              )

              error
          end
        rescue
          error in WeChat.Error ->
            error
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(result))
      |> halt()
    end

    defp fetch(%{"appid" => appid, "authorizer_appid" => authorizer_appid}, adapter_storage) do
      comp_adapter_storage = adapter_storage[:component]
      WeChat.Component.fetch_access_token(appid, authorizer_appid, comp_adapter_storage)
    end

    defp fetch(%{"appid" => appid}, adapter_storage) do
      common_adapter_storage = adapter_storage[:common]
      WeChat.fetch_access_token(appid, common_adapter_storage)
    end

    defp fetch(_, _) do
      :invalid
    end
  end
end
