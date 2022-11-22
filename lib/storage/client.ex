defmodule WeChat.Storage.Client do
  @moduledoc """
  The storage adapter specification for WeChat common application.

  Since we need to temporarily storage some key data(e.g. `access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use `elixir_wechat` in a client side of WeChat `common` application.

  Notice: the scenario as a client, we only need to implement the minimum functions to automatically append the
  required parameters from the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat Official Account Platform application

      defmodule MyAppStorageClient do
        @behaviour WeChat.Storage.Client

        @impl true
        def fetch_access_token(appid, args) do
          access_token = "Get access_token by appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def fetch_ticket(appid, type, args) do
          ticket = "Get jsapi-ticket/card-ticket from your persistence..."
          {:ok, ticket}
        end

        @impl true
        def refresh_access_token(appid, access_token, args) do
          access_token = "Refresh access_token by appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

      end

  #### Use `MyAppStorageClient`

  Global configure `MyAppStorageClient`

      defmodule Client do
        use WeChat,
          adapter_storage: {MyAppStorageClient, args}
      end

      defmodule Client do
        use WeChat,
          adapter_storage: MyAppStorageClient
      end

  Dynamically set `MyAppStorageClient` when call `WeChat.request/2`

      WeChat.request(:post, url: ..., adapter_storage: {MyAppStorageClient, args}, ...)
      WeChat.request(:post, url: ..., adapter_storage: MyAppStorageClient, ...)

  Notice: The above `args` will be returned back into each implement of callback function, if not input it, `args` will be
  as an empty list in callback.
  """

  @doc """
  Fetch access_token of WeChat common application.
  """
  @callback fetch_access_token(appid :: String.t(), args :: term()) :: {:ok, %WeChat.Token{}}

  @doc """
  Refresh access_token of WeChat common application.
  """
  @callback refresh_access_token(appid :: String.t(), access_token :: String.t(), args :: term()) ::
              {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Fetch ticket of WeChat common application, the option of `type` parameter is "wx_card" or "jsapi"(refer WeChat Official document).
  """
  @callback fetch_ticket(appid :: String.t(), type :: String.t(), args :: term()) ::
              {:ok, %WeChat.Ticket{}} | {:error, %WeChat.Error{}}
end

defmodule WeChat.Storage.ComponentClient do
  @moduledoc """
  The storage adapter specification for WeChat component application.

  Since we need to temporarily storage some key data(e.g. `access_token`/`component_access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use `elixir_wechat` in a client side of WeChat `component` application.

  Notice: as a client, we only need to implement the minimum functions to automatically append the
  required parameters from the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat third-party platform application

      defmodule MyComponentAppStorageClient do
        @behaviour WeChat.Storage.ComponentClient

        @impl true
        def fetch_access_token(appid, authorizer_appid, args) do
          access_token = "Get authorizer's access_token by appid and authorizer appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl ture
        def fetch_component_access_token(appid, args) do
          access_token = "Get component access_token by component appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def refresh_access_token(appid, authorizer_appid, access_token, args) do
          access_token = "Refresh access_token by appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def refresh_component_access_token(appid, component_access_token, args) do
          access_token = "Refresh component access_token by component appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def fetch_ticket(appid, type, args) do
          ticket = "Get jsapi-ticket/card-ticket from your persistence..."
          {:ok, ticket}
        end
      end

  #### Use `MyComponentAppStorageClient`

  Global configure `MyComponentAppStorageClient`

      defmodule Client do
        use WeChat,
          adapter_storage: {MyComponentAppStorageClient, args}
      end

      defmodule Client do
        use WeChat,
          adapter_storage: MyComponentAppStorageClient
      end

  Dynamically set `MyComponentAppStorageClient` when call `WeChat.request/2`

      WeChat.request(:post, url: ..., adapter_storage: {MyComponentAppStorageClient, args}, ...)
      WeChat.request(:post, url: ..., adapter_storage: MyComponentAppStorageClient, ...)

  Notice: The above `args` will be returned back into each implement of callback function, if not input it, `args` will be
  as an empty list in callback.
  """

  @doc """
  Fetch authorizer's access_token in WeChat component application.
  """
  @callback fetch_access_token(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              args :: term()
            ) :: {:ok, %WeChat.Token{}}

  @doc """
  Fetch access_token of WeChat component application.
  """
  @callback fetch_component_access_token(appid :: String.t(), args :: term()) ::
              {:ok, %WeChat.Token{}}

  @doc """
  Refresh authorizer's access_token in WeChat component application.
  """
  @callback refresh_access_token(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              access_token :: String.t(),
              args :: term()
            ) :: {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}


  @doc """
  Refresh access_token of WeChat component application.
  """
  @callback refresh_component_access_token(
              appid :: String.t(),
              component_access_token :: String.t(),
              args :: term()
            ) :: {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Fetch authorizer's ticket of WeChat component application, the option of `type` parameter is "wx_card" or "jsapi"(refer WeChat Official document).
  """
  @callback fetch_ticket(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              type :: String.t(),
              args :: term()
            ) ::
              {:ok, %WeChat.Ticket{}} | {:error, %WeChat.Error{}}
end
