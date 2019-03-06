defmodule WeChat.Adapter.Storage.Hub do
  @moduledoc """
  The storage adapter specification for WeChat common application.

  Since we need to storage(cache) some key data(e.g. `access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use this library in a `:hub` side of WeChat common application.

  Notice: In the `:hub` scenario, we need to implement the completed functions to maintain the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat Official Account Platform application

      defmodule MyApp.Storage.Hub do
        @behaviour WeChat.Adapter.Storage.Hub

        @impl true
        def get_secret_keya(appid) do
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
        def delete_access_token(appid, access_token) do
          # Delete access_token by appid from your persistence
        end

      end
  """

  @doc """
  Get secret_key of WeChat common application.
  """
  @callback get_secret_key(appid :: String.t()) :: String.t() | nil | %WeChat.Error{}

  @doc """
  Get access_token of WeChat common application.

  ## Example

      get_access_token(appid) 
  """
  @callback get_access_token(appid :: String.t()) :: %WeChat.Token{} | nil | %WeChat.Error{}

  @doc """
  Save access_token of WeChat common application.

  ## Example

      save_access_token(appid, access_token)
  """
  @callback save_access_token(appid :: String.t(), access_token :: String.t()) :: term()

  @doc """
  Delete access_token of WeChat common application.

  ## Example

      delete_access_token(appid, access_token)
  """
  @callback delete_access_token(appid :: String.t(), access_token :: String.t()) :: term()
end

defmodule WeChat.Adapter.Storage.ComponentHub do
  @moduledoc """
  The storage adapter specification for WeChat component application.

  Since we need to storage(cache) some key data(e.g. `access_token`/`component_access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use this library in a `:hub` side of WeChat component application.
  
  Notice: In the `:hub` scenario, we need to implement the completed functions to maintain the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat 3rd-party Platform application

      defmodule MyComponentApp.Storage.Hub do
        @behaviour WeChat.Adapter.Storage.ComponentHub

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
        def delete_access_token(appid, authorizer_appid, access_token) do
          # Delete authorizer's access_token for WeChat component application from your persistence
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
        def delete_component_access_token(appid, component_access_token) do
          # Delete access_token of WeChat component application
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
  @callback get_secret_key(appid :: String.t()) :: String.t() | nil | %WeChat.Error{}

  @doc """
  Get authorizer's access_token for WeChat component application.

  ## Example

      get_access_token(appid, authorizer_appid)
  """
  @callback get_access_token(appid :: String.t(), authorizer_appid :: String.t()) ::
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
              refresh_token :: String.t()
            ) :: term()

  @doc """
  Delete authorizer's access_token for WeChat component application.

  ## Example

      delete_access_token(
        appid,
        authorizer_appid,
        access_token
      )
  """
  @callback delete_access_token(
              appid :: String.t(),
              authorizer_appid :: String.t(),
              access_token :: String.t()
            ) :: term()

  @doc """
  Get access_token of WeChat component application.

  ## Example

      get_component_access_token(appid)
  """
  @callback get_component_access_token(appid :: String.t()) ::
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
              appid :: String.t(), component_access_token :: String.t()
            ) :: term()

  @doc """
  Delete access_token of WeChat component application.

  ## Example

      delete_component_access_token(
        appid,
        component_access_token
      )
  """
  @callback delete_component_access_token(
              appid :: String.t(),
              component_access_token :: String.t()
            ) :: term()

  @doc """
  Get component_verify_ticket of WeChat component application.
  """
  @callback get_component_verify_ticket(appid :: String.t()) :: String.t() | nil | %WeChat.Error{}

  @doc """
  Save component_verify_ticket of WeChat component application.

  ## Example

      save_component_verify_ticket(appid, component_verify_ticket)
  """
  @callback save_component_verify_ticket(
              appid :: String.t(),
              component_verify_ticket :: String.t()
            ) :: term()
end
