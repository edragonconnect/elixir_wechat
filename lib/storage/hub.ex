defmodule WeChat.Storage.Hub do
  @moduledoc """
  The storage adapter specification for WeChat common application.

  Since we need to temporarily storage some key data(e.g. `access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use `elixir_wechat` in the centralization nodes(hereinafter "hub") side
  of WeChat common application.

  Notice: the scenario as a hub, we need to implement the completed functions to maintain the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat Official Account Platform application

      defmodule MyAppStorageHub do
        @behaviour WeChat.Storage.Hub

        @impl true
        def fetch_secret_key(appid, args) do
          secret_key = "Get secret_key by appid from your persistence..."
          secret_key
        end

        @impl true
        def fetch_access_token(appid, args) do
          access_token = "Get access_token by appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def fetch_ticket(appid, type, args) do
          ticket = "Get ticket by appid from your persistence..."
          {:ok, ticket}
        end

        @impl true
        def refresh_access_token(appid, access_token, args) do
          access_token = "Refresh access_token by appid from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def save_access_token(appid, access_token, args) do
          # Save access_token by appid to your persistence
        end

        @impl true
        def save_ticket(appid, ticket, type, args) do
          # Save ticket by appid to your persistence
        end
      end

  #### Use `MyAppStorageHub`
  
  Global configure `MyAppStorageHub`

      defmodule Client do
        use WeChat,
          adapter_storage: {MyAppStorageHub, args}
      end

      defmodule Client do
        use WeChat,
          adapter_storage: MyAppStorageHub
      end

  Dynamically set `MyAppStorageHub` when call `WeChat.request/2`

      WeChat.request(:post, url: ..., adapter_storage: {MyAppStorageHub, args}, ...)
      WeChat.request(:post, url: ..., adapter_storage: MyAppStorageHub, ...)

  Notice: The above `args` will be returned back into each implement of callback function, if not input it, `args` will be
  as an empty list in callback.
  """

  @doc """
  Fetch secret_key of WeChat common application.
  """
  @callback fetch_secret_key(appid :: String.t(), args :: list()) :: {:ok, String.t()} | {:error, %WeChat.Error{}}

  @doc """
  Fetch access_token of WeChat common application.
  """
  @callback fetch_access_token(appid :: String.t(), args :: list()) :: {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Save access_token of WeChat common application.
  """
  @callback save_access_token(appid :: String.t(), access_token :: String.t(), args :: list()) :: term()

  @doc """
  Refresh access_token of WeChat common application.
  """
  @callback refresh_access_token(appid :: String.t(), access_token :: String.t(), args :: list()) ::
    {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Save ticket of WeChat common application, the option of `type` parameter is "wx_card" or "jsapi"(refer WeChat Official document).
  """
  @callback save_ticket(appid :: String.t(), ticket :: String.t(), type :: String.t(), args :: list()) :: term()

  @doc """
  Fetch ticket of WeChat common application, the option of `type` parameter is "wx_card" or "jsapi"(refer WeChat Official document).
  """
  @callback fetch_ticket(appid :: String.t(), type :: String.t(), args :: list()) ::
    {:ok, String.t()} | {:error, %WeChat.Error{}}
end

defmodule WeChat.Storage.ComponentHub do
  @moduledoc """
  The storage adapter specification for WeChat component application.

  Since we need to temporarily storage some key data(e.g. `access_token`/`component_access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use `elixir_wechat` in the centralization nodes(hereinafter "hub") side
  of WeChat component application.

  Notice: the scenario as a hub, we need to implement the completed functions to maintain the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat 3rd-party Platform application

      defmodule MyComponentAppStorageHub do
        @behaviour WeChat.Storage.ComponentHub

        @impl true
        def fetch_access_token(appid, authorizer_appid, args) do
          access_token = "Get authorizer's access_token for WeChat component application from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def fetch_component_access_token(appid, args) do
          access_token = "Get component access_token for WeChat component application from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def fetch_component_verify_ticket(appid, args) do
          component_verify_ticket = "Get component_verify_ticket for WeChat component application from your persistence..."
          {:ok, component_verify_ticket}
        end

        @impl true
        def fetch_secret_key(appid, args) do
          secret_key = "Get component application secret_key from your persistence..."
          secret_key
        end

        @impl true
        def fetch_ticket(appid, authorizer_appid, type, args) do
          ticket = "Get authorizer account's ticket for WeChat component application from your persistence..."
          {:ok, ticket}
        end

        @impl true
        def refresh_access_token(appid, authorizer_appid, access_token, args) do
          access_token = "Refresh authorizer's access_token for WeChat component application from your persistence..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def refresh_component_access_token(appid, component_access_token, args) do
          access_token = "Refresh access_token of WeChat component application..."
          {:ok, %WeChat.Token{access_token: access_token}}
        end

        @impl true
        def save_access_token(appid, authorizer_appid, access_token, refresh_token, args) do
          # Save authorizer's access_token and its refresh_token to your persistence
        end

        @impl true
        def save_component_access_token(appid, component_access_token, args) do
          # Save access_token of WeChat component application
        end

        @impl true
        def save_component_verify_ticket(appid, component_verify_ticket, args) do
          # Save component_verify_ticket to your persistence
        end

        @impl true
        def save_ticket(appid, authorizer_appid, ticket, type, args) do
          # Save authorizer account's ticket to your persistence
        end
      end

  #### Use `MyComponentAppStorageHub`
  
  Global configure `MyComponentAppStorageHub`

      defmodule Client do
        use WeChat,
          adapter_storage: {MyComponentAppStorageHub, args}
      end

      defmodule Client do
        use WeChat,
          adapter_storage: MyComponentAppStorageHub
      end

  Dynamically set `MyComponentAppStorageHub` when call `WeChat.request/2`

      WeChat.request(:post, url: ..., adapter_storage: {MyComponentAppStorageHub, args}, ...)
      WeChat.request(:post, url: ..., adapter_storage: MyComponentAppStorageHub, ...)

  Notice: The above `args` will be returned back into each implement of callback function, if not input it, `args` will be
  as an empty list in callback.
  """

  @doc """
  Get secret_key of WeChat component application.
  """
  @callback fetch_secret_key(appid :: String.t(), args :: list()) :: {:ok, String.t()} | {:error, %WeChat.Error{}}

  @doc """
  Get authorizer's access_token for WeChat component application.
  """
  @callback fetch_access_token(appid :: String.t(), authorizer_appid :: String.t(), args :: list()) ::
    {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Save authorizer's access_token for WeChat component application.
  """
  @callback save_access_token(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              access_token :: String.t(),
              refresh_token :: String.t(),
              args :: list()
            ) :: term()

  @doc """
  Refresh authorizer's access_token for WeChat component application.
  """
  @callback refresh_access_token(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              access_token :: String.t(),
              args :: list()
            ) :: {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Get access_token of WeChat component application.
  """
  @callback fetch_component_access_token(appid :: String.t(), args :: list()) ::
    {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Save access_token of WeChat component application.
  """
  @callback save_component_access_token(
              appid :: String.t(),
              component_access_token :: String.t(),
              args :: list()
            ) :: term()

  @doc """
  Refresh access_token of WeChat component application.
  """
  @callback refresh_component_access_token(
              appid :: String.t(),
              component_access_token :: String.t(),
              args :: list()
            ) :: {:ok, %WeChat.Token{}} | {:error, %WeChat.Error{}}

  @doc """
  Fetch component_verify_ticket of WeChat component application.
  """
  @callback fetch_component_verify_ticket(appid :: String.t(), args :: list()) ::
    {:ok, String.t()} | {:error, %WeChat.Error{}}

  @doc """
  Save component_verify_ticket of WeChat component application.
  """
  @callback save_component_verify_ticket(
              appid :: String.t(),
              component_verify_ticket :: String.t(),
              args :: list()
            ) :: term()

  @doc """
  Save authorizer account's ticket in WeChat component application.
  """
  @callback save_ticket(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              ticket :: String.t(),
              type :: String.t(),
              args :: list()
            ) :: term()

  @doc """
  Fetch authorizer account's ticket in WeChat component application.
  """
  @callback fetch_ticket(appid :: String.t(), authorizer_appid :: String.t(), type :: String.t(), args :: list()) ::
    {:ok, String.t()} | {:error, %WeChat.Error{}}
end
