defmodule WeChat.Storage.Adapter.DefaultClient do
  @moduledoc false

  @behaviour WeChat.Storage.Client

  alias WeChat.Storage.DefaultHubConnector, as: Connector
  alias WeChat.Error

  @impl true
  def fetch_access_token(appid, args) do
    hub_base_url = Keyword.get(args, :hub_base_url)
    Connector.fetch_access_token(appid, hub_base_url)
  end

  @impl true
  def refresh_access_token(appid, access_token, args) do
    hub_base_url = Keyword.get(args, :hub_base_url)
    Connector.refresh_access_token(appid, access_token, hub_base_url)
  end

  @impl true
  def fetch_ticket(appid, type, args) do
    # currently only support `type` as "jsapi" | "wx_card"
    hub_base_url = Keyword.get(args, :hub_base_url)
    Connector.fetch_ticket(appid, type, hub_base_url)
  end
end

defmodule WeChat.Storage.Adapter.DefaultComponentClient do
  @moduledoc false

  @behaviour WeChat.Storage.ComponentClient

  alias WeChat.Storage.DefaultHubConnector, as: Connector
  alias WeChat.Error

  @impl true
  def fetch_access_token(appid, authorizer_appid, args) do
    hub_base_url = Keyword.get(args, :hub_base_url)
    Connector.fetch_access_token(appid, authorizer_appid, hub_base_url)
  end

  @impl true
  def fetch_component_access_token(appid, args) do
    hub_base_url = Keyword.get(args, :hub_base_url)
    Connector.fetch_component_access_token(appid, hub_base_url)
  end

  @impl true
  def refresh_access_token(
        appid,
        authorizer_appid,
        access_token,
        args
      ) do
    hub_base_url = Keyword.get(args, :hub_base_url)
    Connector.refresh_access_token(appid, authorizer_appid, access_token, hub_base_url)
  end

  @impl true
  def fetch_ticket(appid, authorizer_appid, type, args) do
    hub_base_url = Keyword.get(args, :hub_base_url)
    # Currently, `type` supports "jsapi" | "wx_card"
    Connector.fetch_ticket(appid, authorizer_appid, type, hub_base_url)
  end
end

defmodule WeChat.Storage.DefaultHubConnector do
  @moduledoc false

  require Logger

  alias WeChat.Error

  def refresh_access_token(appid, access_token, hub_base_url) do
    Logger.info(
      "send refresh_token request to wechat hub for appid: #{inspect(appid)}, access_token: #{
        inspect(access_token)
      }"
    )

    token =
      hub_base_url
      |> client()
      |> Tesla.post("/refresh/access_token", %{appid: appid, access_token: access_token})
      |> response_to_access_token()

    Logger.info(
      "received refreshed token from wechat hub: #{inspect(token)} for appid: #{inspect(appid)}"
    )

    token
  end

  def refresh_access_token(appid, authorizer_appid, access_token, hub_base_url) do
    Logger.info(
      "send refresh_token request to wechat hub for appid: #{inspect(appid)} with authorizer_appid: #{
        inspect(authorizer_appid)
      }, access_token: #{inspect(access_token)}"
    )

    token =
      hub_base_url
      |> client()
      |> Tesla.post("/refresh/access_token", %{appid: appid, authorizer_appid: authorizer_appid, access_token: access_token})
      |> response_to_access_token()

    Logger.info(
      "received access token from wechat hub: #{inspect(token)} for appid: #{inspect(appid)} with authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    token
  end

  def fetch_access_token(appid, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get("/client/access_token", query: [appid: appid])
    |> response_to_access_token()
  end

  def fetch_access_token(appid, authorizer_appid, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get("/client/access_token", query: [appid: appid, authorizer_appid: authorizer_appid])
    |> response_to_access_token()
  end

  def fetch_component_access_token(appid, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get("/client/component_access_token", query: [appid: appid])
    |> response_to_access_token()
  end

  def fetch_ticket(appid, type, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get("/client/ticket", query: [appid: appid, type: type])
    |> response_to_ticket()
  end

  def fetch_ticket(appid, authorizer_appid, type, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get("/client/ticket", query: [appid: appid, authorizer_appid: authorizer_appid, type: type])
    |> response_to_ticket()
  end

  defp client(hub_base_url) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, hub_base_url},
      {Tesla.Middleware.Retry, delay: 500, max_retries: 10},
      Tesla.Middleware.JSON
    ])
  end

  defp response_to_access_token(
         {:ok, %{status: 200, body: %{"access_token" => access_token} = body}}
       )
       when access_token != nil and access_token != "" do
    {
      :ok,
      %WeChat.Token{
        access_token: access_token,
        refresh_token: Map.get(body, "refresh_token")
      }
    }
  end

  defp response_to_access_token({:ok, %{status: status, body: body}}) do
    {:error,
     %Error{reason: :fail_fetch_access_token, errcode: -1, http_status: status, message: body}}
  end

  defp response_to_access_token({:error, error}) do
    {:error, %Error{reason: :fail_fetch_access_token, errcode: -1, message: error}}
  end

  defp response_to_ticket({:ok, %{status: 200, body: %{"ticket" => ticket}}})
       when ticket != nil and ticket != "" do
    {:ok, ticket}
  end

  defp response_to_ticket({:ok, %{status: status, body: body}}) do
    {:error, %Error{reason: :fail_fetch_ticket, errcode: -1, http_status: status, message: body}}
  end

  defp response_to_ticket({:error, error}) do
    {:error, %Error{reason: :fail_fetch_ticket, errcode: -1, message: error}}
  end
end
