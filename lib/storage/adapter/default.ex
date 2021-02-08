defmodule WeChat.Storage.Adapter.DefaultClient do
  @moduledoc """
  For `common` application.

  ```
  defmodule MyClient do
    use WeChat,
      adapter_storage: {:default, "http://localhost:4000"},
      appid: "MyAppID"
  end
  ```

  The above equals as below

  ```
  defmodule MyClient do
    use WeChat,
      adapter_storage: {
        WeChat.Storage.Adapter.DefaultClient,
        "http://localhost:4000"
      },
      appid: "MyAppID"
  end
  ```

  When uses the `{:default, "MyHubBaseURL"}`, there requires some HTTP API functions are provided by the hub web app server,
  let's take "MyHubBaseURL" as "http://localhost:4000" for example.

  ### Refresh access token

  ```
  Request
  - method: POST http://localhost:4000/refresh/access_token
  - body: %{"appid" => "MyAppID", "access_token" => "CurrentExpiryAccessToken"}
  - body format: json

  Response
  - success body: %{"access_token" => "...", "expires_in" => integer(), "timestamp" => integer()}
  - error body: any content is acceptable will be return back into `WeChat.Error`
  ```

  ### Fetch access token

  ```
  Request
  - method: GET http://localhost:4000/client/access_token
  - query string: appid="MyAppID"

  Response
  - success body: %{"access_token" => "...", "expires_in" => integer(), "timestamp" => integer()}
  - error body: any error content is acceptable will be return back into `WeChat.Error`
  ```

  ### Fetch jsapi-ticket/card-ticket

  ```
  Request
  - method: GET http://localhost:4000/client/ticket
  - query string: appid="MyAppID"&type=jsapi or appid="MyAppID"&type=wx_card

  Response
  - success body: %{"ticket" => "...", "expires_in" => integer(), timestamp => integer(), "type" => "jsapi" | "wx_card"}
  - error body: any error content is acceptable will be return back into `WeChat.Error`
  ```
  """

  @behaviour WeChat.Storage.Client

  use WeChat.Registry

  alias WeChat.Storage.DefaultHubConnector, as: Connector
  alias WeChat.Error

  @impl true
  @decorate cache()
  def fetch_access_token(appid, hub_base_url) do
    Connector.fetch_access_token(appid, hub_base_url)
  end

  @impl true
  @decorate cache()
  def refresh_access_token(appid, access_token, hub_base_url) do
    Connector.refresh_access_token(appid, access_token, hub_base_url)
  end

  @impl true
  @decorate cache()
  def fetch_ticket(appid, type, hub_base_url) do
    # currently only support `type` as "jsapi" | "wx_card"
    Connector.fetch_ticket(appid, type, hub_base_url)
  end
end

defmodule WeChat.Storage.Adapter.DefaultComponentClient do
  @moduledoc """
  For `component` application.

  ```
  defmodule MyClient do
    use WeChat.Component,
      adapter_storage: {:default, "http://localhost:4000"},
      appid: "MyComponentAppID"
  end
  ```

  The above equals as below

  ```
  defmodule MyClient do
    use WeChat.Component,
      adapter_storage: {
        WeChat.Storage.Adapter.DefaultComponentClient,
        "http://localhost:4000"
      },
      appid: "MyComponentAppID"
  end
  ```

  When uses the `{:default, "MyHubBaseURL"}`, there requires some HTTP API functions are provided by the hub web app server,
  let's take "MyHubBaseURL" as "http://localhost:4000" for example.

  ### Refresh authorizer access_token

  ```
  Request
  - method: POST http://localhost:4000/refresh/access_token
  - body: %{"appid" => "Your3rdComponentAppID", "authorizer_appid" => "YourAuthorizerAppID", "access_token" => "CurrentExpiryAccessToken"}
  - body format: json

  Response
  - success body: %{"access_token" => "...", "expires_in" => integer(), "timestamp" => integer()}
  - error body: any content is acceptable will be return back into `WeChat.Error`
  ```

  ### Fetch access_token

  ```
  Request
  - method: GET http://localhost:4000/client/access_token
  - query string: appid="MyAppID"

  Response
  - success body: %{"access_token" => "...", "expires_in" => integer(), "timestamp" => integer()}
  - error body: any error content is acceptable will be return back into `WeChat.Error`
  ```

  ### Fetch jsapi-ticket/card-ticket

  ```
  Request
  - method: GET http://localhost:4000/client/ticket
  - query string: appid="MyAppID"&type=jsapi or appid="MyAppID"&type=wx_card

  Response
  - success body: %{"ticket" => "...", "expires_in" => integer(), "timestamp" => integer(), "type" => "jsapi" | "wx_card"}
  - error body: any error content is acceptable will be return back into `WeChat.Error`
  ```
  """

  @behaviour WeChat.Storage.ComponentClient

  use WeChat.Registry

  alias WeChat.Storage.DefaultHubConnector, as: Connector
  alias WeChat.Error

  @impl true
  @decorate cache()
  def fetch_access_token(appid, authorizer_appid, hub_base_url) do
    Connector.fetch_access_token(appid, authorizer_appid, hub_base_url)
  end

  @impl true
  @decorate cache()
  def fetch_component_access_token(appid, hub_base_url) do
    Connector.fetch_component_access_token(appid, hub_base_url)
  end

  @impl true
  @decorate cache()
  def refresh_access_token(
        appid,
        authorizer_appid,
        access_token,
        hub_base_url
      ) do
    Connector.refresh_access_token(appid, authorizer_appid, access_token, hub_base_url)
  end

  @impl true
  @decorate cache()
  def fetch_ticket(appid, authorizer_appid, type, hub_base_url) do
    # Currently, `type` supports "jsapi" | "wx_card"
    Connector.fetch_ticket(appid, authorizer_appid, type, hub_base_url)
  end
end

defmodule WeChat.Storage.DefaultHubConnector do
  @moduledoc false

  require Logger

  alias WeChat.{Error, Url}

  def refresh_access_token(appid, access_token, hub_base_url) do
    Logger.info(
      "send refresh_token request to WeChat hub for appid: #{inspect(appid)}, access_token: #{
        inspect(access_token)
      }"
    )

    token =
      hub_base_url
      |> client()
      |> Tesla.post(Url.to_refresh_access_token(), %{appid: appid, access_token: access_token})
      |> response_to_access_token()

    Logger.info(
      "received refreshed token from WeChat hub: #{inspect(token)} for appid: #{inspect(appid)}"
    )

    token
  end

  def refresh_access_token(appid, authorizer_appid, access_token, hub_base_url) do
    Logger.info(
      "send refresh_token request to WeChat hub for appid: #{inspect(appid)} with authorizer_appid: #{
        inspect(authorizer_appid)
      }, access_token: #{inspect(access_token)}"
    )

    token =
      hub_base_url
      |> client()
      |> Tesla.post(Url.to_refresh_access_token(), %{
        appid: appid,
        authorizer_appid: authorizer_appid,
        access_token: access_token
      })
      |> response_to_access_token()

    Logger.info(
      "received access token from WeChat hub: #{inspect(token)} for appid: #{inspect(appid)} with authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    token
  end

  def fetch_access_token(appid, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get(Url.to_fetch_access_token(), query: [appid: appid])
    |> response_to_access_token()
  end

  def fetch_access_token(appid, authorizer_appid, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get(Url.to_fetch_access_token(),
      query: [appid: appid, authorizer_appid: authorizer_appid]
    )
    |> response_to_access_token()
  end

  def fetch_component_access_token(appid, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get(Url.to_fetch_component_access_token(), query: [appid: appid])
    |> response_to_access_token()
  end

  def fetch_ticket(appid, type, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get(Url.to_fetch_ticket(), query: [appid: appid, type: type])
    |> response_to_ticket()
  end

  def fetch_ticket(appid, authorizer_appid, type, hub_base_url) do
    hub_base_url
    |> client()
    |> Tesla.get(Url.to_fetch_ticket(),
      query: [appid: appid, authorizer_appid: authorizer_appid, type: type]
    )
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
         {:ok,
          %{
            status: 200,
            body: %{
              "access_token" => access_token,
              "timestamp" => timestamp,
              "expires_in" => expires_in
            }
          }}
       )
       when access_token != nil and access_token != "" and
              is_integer(timestamp) and is_integer(expires_in) do
    {
      :ok,
      %WeChat.Token{
        access_token: access_token,
        timestamp: timestamp,
        expires_in: expires_in
      }
    }
  end

  defp response_to_access_token(
         {:ok,
          %{
            body: %{
              "errcode" => errcode,
              "http_status" => http_status,
              "message" => message,
              "reason" => reason
            }
          }}
       ) do
    {
      :error,
      %Error{
        errcode: errcode,
        http_status: http_status,
        message: message,
        reason: reason
      }
    }
  end

  defp response_to_access_token({:error, error}) do
    {
      :error,
      %Error{
        reason: "fail_fetch_access_token",
        errcode: -1,
        message: error
      }
    }
  end

  defp response_to_ticket(
         {:ok,
          %{
            status: 200,
            body:
              %{"ticket" => ticket, "timestamp" => timestamp, "expires_in" => expires_in} = body
          }}
       )
       when ticket != nil and ticket != "" and
              is_integer(timestamp) and is_integer(expires_in) do
    {
      :ok,
      %WeChat.Ticket{
        value: ticket,
        type: Map.get(body, "type"),
        timestamp: timestamp,
        expires_in: expires_in
      }
    }
  end

  defp response_to_ticket({:ok, %{status: status, body: body}}) do
    {:error, %Error{reason: "fail_fetch_ticket", errcode: -1, http_status: status, message: body}}
  end

  defp response_to_ticket({:error, error}) do
    {:error, %Error{reason: "fail_fetch_ticket", errcode: -1, message: error}}
  end
end
