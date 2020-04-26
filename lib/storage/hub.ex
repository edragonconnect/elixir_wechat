defmodule WeChat.Storage.Hub do
  @moduledoc """
  The storage adapter specification for WeChat common application.

  Since we need to storage(cache) some key data(e.g. `access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use this library in a `:hub` side of WeChat common application.

  Notice: In the `:hub` scenario, we need to implement the completed functions to maintain the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat Official Account Platform application

      defmodule MyApp.Storage.Hub do
        @behaviour WeChat.Storage.Hub.Common

        @impl true
        def get_secret_key(appid) do
          secret_key = "Get secret_key by appid from your persistence..."
          secret_key
        end

        @impl true
        def get_access_token(appid) do
          access_token = "Get access_token by appid from your persistence..."
          access_token
        end

        @impl true
        def save_access_token(appid, access_token) do
          # Save access_token by appid to your persistence
        end

        @impl true
        def refresh_access_token(appid, access_token) do
          # Refresh access_token by appid from your persistence
        end

      end
  """

  @doc """
  Get secret_key of WeChat common application.
  """
  @callback secret_key(appid :: String.t(), args :: list()) :: String.t() | nil | %WeChat.Error{}

  @doc """
  Get access_token of WeChat common application.

  ## Example

      fetch_access_token(appid) 
  """
  @callback fetch_access_token(appid :: String.t(), args :: list()) :: %WeChat.Token{} | nil | %WeChat.Error{}

  @doc """
  Save access_token of WeChat common application.

  ## Example

      save_access_token(appid, access_token)
  """
  @callback save_access_token(appid :: String.t(), access_token :: String.t(), args :: list()) :: term()

  @doc """
  Refresh access_token of WeChat common application.

  ## Example

      refresh_access_token(appid, access_token)
  """
  @callback refresh_access_token(appid :: String.t(), access_token :: String.t(), args :: list()) :: String.t()

  @doc """
  Save ticket of WeChat common application.

  ## Example
   
      save_ticket(appid, ticket, "wx_card")
      save_ticket(appid, ticket, "jsapi")
  """
  @callback save_ticket(appid :: String.t(), ticket :: String.t(), type :: String.t(), args :: list()) :: term()

  @doc """
  Get ticket of WeChat common application.

  ## Example

      fetch_ticket(appid, "wx_card")
      fetch_ticket(appid, "jsapi")
  """
  @callback fetch_ticket(appid :: String.t(), type :: String.t(), args :: list()) ::
              String.t() | nil | %WeChat.Error{}
end

defmodule WeChat.Storage.ComponentHub do
  @moduledoc """
  The storage adapter specification for WeChat component application.

  Since we need to storage(cache) some key data(e.g. `access_token`/`component_access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use this library in a `:hub` side of WeChat component application.

  Notice: In the `:hub` scenario, we need to implement the completed functions to maintain the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat 3rd-party Platform application

      defmodule MyComponentApp.Storage.Hub do
        @behaviour WeChat.Storage.Hub.Component

        @impl true
        def get_secret_key(appid) do
          secret_key = "Get component application secret_key from your persistence..."
          secret_key
        end

        @impl true
        def get_access_token(appid, authorizer_appid) do
          access_token = "Get authorizer's access_token for WeChat component application from your persistence..."
          access_token
        end

        @impl true
        def save_access_token(appid, authorizer_appid, access_token, refresh_token) do
          # Save authorizer's access_token and its refresh_token to your persistence
        end

        @impl true
        def refresh_access_token(appid, authorizer_appid, access_token) do
          # Refresh authorizer's access_token for WeChat component application from your persistence
        end

        @impl true
        def get_component_access_token(appid) do
          access_token = "Get component access_token for WeChat component application from your persistence..."
          access_token
        end

        @impl true
        def save_component_access_token(appid, component_access_token) do
          # Save access_token of WeChat component application
        end

        @impl true
        def refresh_component_access_token(appid, component_access_token) do
          # Refresh access_token of WeChat component application
        end

        @impl true
        def get_component_verify_ticket(appid) do
          component_verify_ticket = "Get component_verify_ticket for WeChat component application from your persistence..."
          component_verify_ticket
        end

        @impl true
        def save_component_verify_ticket(appid, component_verify_ticket) do
          # Save component_verify_ticket to your persistence
        end
      end
  """

  @doc """
  Get secret_key of WeChat component application.
  """
  @callback secret_key(appid :: String.t(), args :: list()) :: String.t() | nil | %WeChat.Error{}

  @doc """
  Get authorizer's access_token for WeChat component application.

  ## Example

      fetch_access_token(appid, authorizer_appid)
  """
  @callback fetch_access_token(appid :: String.t(), authorizer_appid :: String.t(), args :: list()) ::
              %WeChat.Token{} | nil | %WeChat.Error{}

  @doc """
  Save authorizer's access_token for WeChat component application.

  ## Example

      save_access_token(
        appid,
        authorizer_appid,
        access_token,
        refresh_token,
      )
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

  ## Example

      refresh_access_token(
        appid,
        authorizer_appid,
        access_token
      )
  """
  @callback refresh_access_token(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              access_token :: String.t(),
              args :: list()
            ) :: String.t()

  @doc """
  Get access_token of WeChat component application.

  ## Example

      fetch_component_access_token(appid)
  """
  @callback fetch_component_access_token(appid :: String.t(), args :: list()) ::
              %WeChat.Token{} | nil | %WeChat.Error{}

  @doc """
  Save access_token of WeChat component application.

  ## Example

      save_component_access_token(
        appid,
        component_access_token
      )
  """
  @callback save_component_access_token(
              appid :: String.t(),
              component_access_token :: String.t(),
              args :: list()
            ) :: term()

  @doc """
  Refresh access_token of WeChat component application.

  ## Example

      refresh_component_access_token(
        appid,
        component_access_token
      )
  """
  @callback refresh_component_access_token(
              appid :: String.t(),
              component_access_token :: String.t(),
              args :: list()
            ) :: String.t()

  @doc """
  Get component_verify_ticket of WeChat component application.
  """
  @callback fetch_component_verify_ticket(appid :: String.t(), args :: list()) ::
              String.t() | nil | %WeChat.Error{}

  @doc """
  Save component_verify_ticket of WeChat component application.

  ## Example

      save_component_verify_ticket(appid, component_verify_ticket)
  """
  @callback save_component_verify_ticket(
              appid :: String.t(),
              component_verify_ticket :: String.t(),
              args :: list()
            ) :: term()

  @doc """
  Save authorizer account's ticket in WeChat component application.

  ## Example

      save_ticket(appid, authorizer_appid, ticket, "wx_card")
      save_ticket(appid, authorizer_appid, ticket, "jsapi")
  """
  @callback save_ticket(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              ticket :: String.t(),
              type :: String.t(),
              args :: list()
            ) :: term()

  @doc """
  Get authorizer account's ticket in WeChat component application.

  ## Example

      fetch_ticket(appid, authorizer_appid, "wx_card")
      fetch_ticket(appid, authorizer_appid, "jsapi")
  """
  @callback fetch_ticket(appid :: String.t(), authorizer_appid :: String.t(), type :: String.t(), args :: list()) ::
              String.t() | nil | %WeChat.Error{}
end
