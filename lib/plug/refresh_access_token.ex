if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.RefreshAccessToken do
    @moduledoc false

    use Plug.Builder

    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :json],
      pass: ["text/*", "application/json"],
      json_decoder: Jason
    )

    require Logger

    def call(conn, opts) do
      conn = conn |> super(opts) |> fetch_query_params()
      adapter_storage = opts[:adapter_storage]
      body = conn.body_params
      result =
        case refresh(body, adapter_storage) do
          {:ok, token} ->
            %{"access_token" => token.access_token}
          error ->
            Logger.error("refresh token occurs an error: #{inspect(error)} with body: #{inspect(body)}")
            %{"error" => "invalid request"}
        end
      
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(result))
      |> halt()
    end

    defp refresh(%{"appid" => appid, "authorizer_appid" => authorizer_appid, "access_token" => access_token}, adapter_storage) do
      comp_adapter_storage = adapter_storage[:component]
      comp_adapter_storage.refresh_access_token(appid, authorizer_appid, access_token, [])
    end
    defp refresh(%{"appid" => appid, "access_token" => access_token}, adapter_storage) do
      common_adapter_storage = adapter_storage[:common]
      common_adapter_storage.refresh_access_token(appid, access_token, [])
    end
    defp refresh(_, _) do
      :invalid
    end
  end
end
