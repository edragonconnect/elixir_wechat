defmodule WeChat.Storage.Default do
  @moduledoc false

  @behaviour WeChat.Adapter.Storage.Client

  alias WeChat.Storage.Default.HubClient

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
end

defmodule WeChat.Storage.ComponentDefault do
  @moduledoc false

  @behaviour WeChat.Adapter.Storage.ComponentClient

  alias WeChat.Storage.Default.HubClient

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
end

defmodule WeChat.Storage.Default.HubClient do
  @moduledoc false

  # This module is used for processing storage (`WeChat.Storage.Default`) by default when use this library as client.

  use Tesla

  plug Tesla.Middleware.BaseUrl, Application.get_env(:elixir_wechat, :hub_base_url)
  plug Tesla.Middleware.Timeout, timeout: 10_000
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

  defp fetch_access_token(response) do
    case response do
      {:ok, env} ->
        status = env.status
        if status == 200 do
          body = env.body
          access_token = Map.get(body, "access_token")
          if access_token == nil do
            Logger.error "occur an error: #{inspect body} while get access_token from hub"
            raise %Error{
              reason: Map.get(body, "reason"),
              errcode: Map.get(body, "errcode"),
              message: Map.get(body, "message")
            }
          else
            access_token
          end
        else
          raise %Error{reason: :fail_fetch_access_token_from_hub, errcode: "http_status_#{status}", message: env.body}
        end
      {:error, error} ->
        raise %Error{reason: :error_fetch_access_token_from_hub, message: error}
    end
  end

end
