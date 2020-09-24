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
              %{"ticket" => Map.get(response.body, "ticket")}

            error ->
              Logger.error(
                "get_ticket occur error: #{inspect(error)} with query_params: #{
                  inspect(query_params)
                }"
              )

              %{"error" => "invalid request"}
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
        adapter_storage: comp_adapter_storage
      )
    end

    defp fetch(%{"appid" => appid, "type" => ticket_type}, adapter_storage) do
      common_adapter_storage = adapter_storage[:common]

      WeChat.request(
        :get,
        appid: appid,
        query: [type: ticket_type],
        url: "/cgi-bin/ticket/getticket",
        adapter_storage: common_adapter_storage
      )
    end

    defp fetch(_, _) do
      :invalid
    end
  end
end
