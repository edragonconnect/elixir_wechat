if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.RefreshComponentAccessToken do
    @moduledoc false

    use Plug.Builder
    require Logger
    alias WeChat.Http

    def call(conn, opts) do
      conn = conn |> super(opts) |> fetch_query_params()
      adapter_storage = opts[:adapter_storage]
      body = conn.body_params

      result =
        try do
          case refresh_if_expired(body, adapter_storage) do
            {:ok, token} ->
              %{
                "access_token" => token.access_token,
                "expires_in" => token.expires_in,
                "timestamp" => token.timestamp
              }

            {:error, %WeChat.Error{} = error} ->
              Logger.error(
                "fetch access token occurs an error: #{inspect(error)} with body params: #{inspect(body)}"
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

    defp refresh_if_expired(%{"appid" => appid, "access_token" => access_token}, adapter_storage) do
      comp_adapter_storage = adapter_storage[:component]
      token = WeChat.Component.fetch_component_access_token(appid, comp_adapter_storage)

      with {:ok, %{access_token: ^access_token}} <- token,
           true <- token_expired?(access_token) do
        adapter_storage.refresh_component_access_token(appid, access_token, nil)
      else
        false -> token
        _ -> token
      end
    end

    defp refresh_if_expired(_, _) do
      {:error, %WeChat.Error{reason: "invalid_request"}}
    end

    defp token_expired?(access_token) do
      Http.component_client()
      |> Tesla.post(
        "https://api.weixin.qq.com/cgi-bin/openapi/quota/get",
        %{"cgi_path" => "/cgi-bin/message/custom/send"},
        query: [access_token: access_token]
      )
      |> case do
        {:ok, %{status: 200, body: %{"errcode" => 40001}}} -> true
        {:ok, %{status: 200, body: %{"errcode" => 42001}}} -> true
        _ -> false
      end
    end
  end
end
