defmodule WeChat.Storage.Default do
  @moduledoc false

  @behaviour WeChat.Adapter.Storage.Client

  alias WeChat.Storage.Default.HubClient
  alias WeChat.Error

  @impl true
  def get_access_token(appid) do
    access_token = HubClient.get_access_token(appid)
    %WeChat.Token{
      access_token: access_token
    }
  end

  @impl true
  def refresh_access_token(appid, access_token) do
    HubClient.refresh_access_token(appid, access_token)
  end

  @impl true
  def get_ticket(appid, type) when type == "jsapi" or type == "wx_card" do
    HubClient.get_ticket(appid, type)
  end
  def get_ticket(appid, type) do
    raise %Error{reason: :invalid_ticket_type, errcode: "http_status_400", message: "input invalid_ticket_type: #{inspect type} for appid: #{inspect appid}"}
  end

end

defmodule WeChat.Storage.ComponentDefault do
  @moduledoc false

  @behaviour WeChat.Adapter.Storage.ComponentClient

  alias WeChat.Storage.Default.HubClient
  alias WeChat.Error

  @impl true
  def get_access_token(appid, authorizer_appid) do
    access_token = HubClient.get_access_token(appid, authorizer_appid)
    %WeChat.Token{
      access_token: access_token
    }
  end

  @impl true
  def get_component_access_token(appid) do
    access_token = HubClient.get_component_access_token(appid)
    %WeChat.Token{
      access_token: access_token
    }
  end

  @impl true
  def refresh_access_token(
        appid,
        authorizer_appid,
        access_token
      ) do
    HubClient.refresh_access_token(appid, authorizer_appid, access_token)
  end

  @impl true
  def get_ticket(appid, authorizer_appid, type) when type == "jsapi" or type == "wx_card" do
    HubClient.get_ticket(appid, authorizer_appid, type)
  end
  def get_ticket(appid, authorizer_appid, type) do
    raise %Error{reason: :invalid_ticket_type, errcode: "http_status_400", message: "input invalid_ticket_type: #{inspect type} for component_appid: #{inspect appid}, authorizer_appid: #{inspect authorizer_appid}"}
  end
end

defmodule WeChat.Storage.Default.HubClient do
  @moduledoc false

  # This module is used for processing storage (`WeChat.Storage.Default`) by default when use this library as client.

  use Tesla

  plug Tesla.Middleware.BaseUrl, Application.get_env(:elixir_wechat, :hub_base_url)
  plug Tesla.Middleware.Retry, delay: 500, max_retries: 10
  plug Tesla.Middleware.JSON

  require Logger

  alias WeChat.Error

  def refresh_access_token(appid, access_token) do
    Logger.info("send refresh_token request to wechat hub for appid: #{inspect appid}")
    token =
      "/refresh/access_token"
      |> post(%{appid: appid, access_token: access_token})
      |> fetch_access_token()
    Logger.info("received refreshed token from wechat hub: #{inspect token} for appid: #{inspect appid}")
    token
  end

  def refresh_access_token(appid, authorizer_appid, access_token) do
    Logger.info("send refresh_token request to wechat hub for appid: #{inspect appid} with authorizer_appid: #{inspect authorizer_appid}")
    token =
      "/refresh/access_token"
      |> post(%{appid: appid, authorizer_appid: authorizer_appid, access_token: access_token})
      |> fetch_access_token()
    Logger.info("received access token from wechat hub: #{inspect token} for appid: #{inspect appid} with authorizer_appid: #{inspect authorizer_appid}")
    token
  end

  def get_access_token(appid) do
    "/client/access_token"
    |> get(query: [appid: appid])
    |> fetch_access_token()
  end

  def get_access_token(appid, authorizer_appid) do
    "/client/access_token"
    |> get(query: [appid: appid, authorizer_appid: authorizer_appid])
    |> fetch_access_token()
  end

  def get_component_access_token(appid) do
    "/client/component_access_token"
    |> get(query: [appid: appid])
    |> fetch_access_token()
  end

  def get_ticket(appid, type) do
    "/client/ticket"
    |> get(query: [appid: appid, type: type])
    |> fetch_ticket()
  end

  def get_ticket(appid, authorizer_appid, type) do
    "/client/ticket"
    |> get(query: [appid: appid, authorizer_appid: authorizer_appid, type: type])
    |> fetch_ticket()
  end

  defp fetch_access_token(response) do
    case response do
      {:ok, env} ->
        status = env.status
        body = env.body
        if status == 200 do
          access_token = Map.get(body, "access_token")
          if access_token == nil do
            Logger.error "occur an error: #{inspect body} while get access_token from hub"
            raise response_error(body)
          else
            access_token
          end
        else
          raise %Error{reason: :fail_fetch_access_token_from_hub, errcode: "http_status_#{status}", message: body}
        end
      {:error, error} ->
        raise %Error{reason: :error_fetch_access_token_from_hub, message: error}
    end
  end

  defp fetch_ticket(response) do
    case response do
      {:ok, env} ->
        status = env.status
        body = env.body
        if status == 200 do
          ticket = Map.get(body, "ticket")
          if ticket == nil do
            Logger.error "occur an error: #{inspect body} while get ticket from hub"
            raise response_error(body)
          else
            ticket
          end
        else
          raise %Error{reason: :fail_fetch_ticket_from_hub, errcode: "http_status_#{status}", message: body}
        end
      {:error, error} ->
        raise %Error{reason: :error_fetch_ticket_from_hub, message: error}
    end
  end

  defp response_error(body) do
    %Error{reason: Map.get(body, "reason"), errcode: Map.get(body, "errcode"), message: Map.get(body, "message")}
  end

end
