defmodule WeChat.Storage.Adapter.DefaultClient do
  @moduledoc false

  @behaviour WeChat.Storage.Client

  alias WeChat.Storage.DefaultHubConnector, as: Connector
  alias WeChat.Error

  @impl true
  def fetch_access_token(appid) do
    Connector.fetch_access_token(appid)
  end

  @impl true
  def refresh_access_token(appid, access_token) do
    Connector.refresh_access_token(appid, access_token)
  end

  @impl true
  def fetch_ticket(appid, type) do
    # currently only support `type` as "jsapi" | "wx_card"
    Connector.fetch_ticket(appid, type)
  end
end

defmodule WeChat.Storage.Adapter.DefaultComponentClient do
  @moduledoc false

  @behaviour WeChat.Storage.ComponentClient

  alias WeChat.Storage.DefaultHubConnector, as: Connector
  alias WeChat.Error

  @impl true
  def fetch_access_token(appid, authorizer_appid) do
    Connector.fetch_access_token(appid, authorizer_appid)
  end

  @impl true
  def fetch_component_access_token(appid) do
    Connector.fetch_component_access_token(appid)
  end

  @impl true
  def refresh_access_token(
        appid,
        authorizer_appid,
        access_token
      ) do
    Connector.refresh_access_token(appid, authorizer_appid, access_token)
  end

  @impl true
  def fetch_ticket(appid, authorizer_appid, type) do
    # Currently, `type` supports "jsapi" | "wx_card"
    Connector.fetch_ticket(appid, authorizer_appid, type)
  end
end

defmodule WeChat.Storage.DefaultHubConnector do
  @moduledoc false

  use Tesla

  plug(Tesla.Middleware.BaseUrl, Application.get_env(:elixir_wechat, :hub_base_url))
  plug(Tesla.Middleware.Retry, delay: 500, max_retries: 10)
  plug(Tesla.Middleware.JSON)

  require Logger

  alias WeChat.Error

  def refresh_access_token(appid, access_token) do
    Logger.info(
      "send refresh_token request to wechat hub for appid: #{inspect(appid)}, access_token: #{
        inspect(access_token)
      }"
    )

    token =
      "/refresh/access_token"
      |> post(%{appid: appid, access_token: access_token})
      |> response_to_access_token()

    Logger.info(
      "received refreshed token from wechat hub: #{inspect(token)} for appid: #{inspect(appid)}"
    )

    token
  end

  def refresh_access_token(appid, authorizer_appid, access_token) do
    Logger.info(
      "send refresh_token request to wechat hub for appid: #{inspect(appid)} with authorizer_appid: #{
        inspect(authorizer_appid)
      }, access_token: #{inspect(access_token)}"
    )

    token =
      "/refresh/access_token"
      |> post(%{appid: appid, authorizer_appid: authorizer_appid, access_token: access_token})
      |> response_to_access_token()

    Logger.info(
      "received access token from wechat hub: #{inspect(token)} for appid: #{inspect(appid)} with authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    token
  end

  def fetch_access_token(appid) do
    "/client/access_token"
    |> get(query: [appid: appid])
    |> response_to_access_token()
  end

  def fetch_access_token(appid, authorizer_appid) do
    "/client/access_token"
    |> get(query: [appid: appid, authorizer_appid: authorizer_appid])
    |> response_to_access_token()
  end

  def fetch_component_access_token(appid) do
    "/client/component_access_token"
    |> get(query: [appid: appid])
    |> response_to_access_token()
  end

  def fetch_ticket(appid, type) do
    "/client/ticket"
    |> get(query: [appid: appid, type: type])
    |> response_to_ticket()
  end

  def fetch_ticket(appid, authorizer_appid, type) do
    "/client/ticket"
    |> get(query: [appid: appid, authorizer_appid: authorizer_appid, type: type])
    |> response_to_ticket()
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
