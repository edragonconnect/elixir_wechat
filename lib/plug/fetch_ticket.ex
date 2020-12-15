if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.FetchTicket do
    @moduledoc false

    use Plug.Builder

    require Logger

    def call(conn, opts) do
      conn = fetch_query_params(conn)
      query_params = conn.query_params

      result =
        try do
          case fetch(query_params, opts[:adapter_storage]) do
            {:ok, response} ->
              %{
                "ticket" => Map.get(response.body, "ticket"),
                "type" => Map.get(response.body, "type"),
                "expires_in" => Map.get(response.body, "expires_in"),
                "timestamp" => Map.get(response.body, "timestamp")
              }

            {:error, %WeChat.Error{} = error} ->
              Logger.error(
                "get_ticket occur error: #{inspect(error)} with query_params: #{
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

    defp fetch(
           %{"appid" => appid, "authorizer_appid" => authorizer_appid, "type" => ticket_type},
           adapter_storage
         ) do
      comp_adapter_storage = adapter_storage[:component]

      WeChat.request(
        :get,
        appid: appid,
        authorizer_appid: authorizer_appid,
        query: [type: ticket_type],
        url: "/cgi-bin/ticket/getticket",
        adapter_storage: comp_adapter_storage,
        scenario: :hub
      )
    end

    defp fetch(%{"appid" => appid, "type" => ticket_type}, adapter_storage) do
      common_adapter_storage = adapter_storage[:common]

      WeChat.request(
        :get,
        appid: appid,
        query: [type: ticket_type],
        url: "/cgi-bin/ticket/getticket",
        adapter_storage: common_adapter_storage,
        scenario: :hub
      )
    end

    defp fetch(_, _) do
      {
        :error,
        %WeChat.Error{reason: "invalid_request"}
      }
    end
  end
end
