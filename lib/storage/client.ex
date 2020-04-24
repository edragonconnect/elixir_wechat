defmodule WeChat.Storage.Client do
  @moduledoc """
  The storage adapter specification for WeChat common application.

  Since we need to storage(cache) some key data(e.g. `access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use this library in a `:client` side of WeChat common application.

  Notice: In the `:client` scenario, we only need to implement the minimum functions to automatically append the
  required parameters from the persistence.

  ## Writing custom storage adapter

  #### Example for WeChat Official Account Platform application

      defmodule MyApp.Storage.Client do
        @behaviour WeChat.Storage.Client

        @impl true
        def get_access_token(appid) do
          access_token = "Get access_token by appid from your persistence..."
          access_token
        end

        @impl true
        def refresh_access_token(appid, access_token) do
          # Refresh access_token by appid from your persistence
          :ok
        end

      end
  """

  @doc """
  Get access_token of WeChat common application.

  ## Example

      fetch_access_token(appid)
  """
  @callback fetch_access_token(appid :: String.t()) :: %WeChat.Token{} | nil | %WeChat.Error{}

  @doc """
  Refresh access_token of WeChat common application via configured Hub servers

  ## Example

      refresh_access_token(appid, access_token)
  """
  @callback refresh_access_token(appid :: String.t(), access_token :: String.t()) :: String.t()

  @doc """
  Get ticket of WeChat common application.

  ## Example
  
      ticket_from_hub(appid, "wx_card")
      ticket_from_hub(appid, "jsapi")
  """
  @callback fetch_ticket(appid :: String.t(), type :: String.t()) :: String.t() | nil | %WeChat.Error{}

end

defmodule WeChat.Storage.ComponentClient do
  @moduledoc """
  The storage adapter specification for WeChat component application.

  Since we need to storage(cache) some key data(e.g. `access_token`/`component_access_token`) for invoking WeChat APIs, this module
  is used for customizing the persistence when use this library in a `:client` side of WeChat component application.

  ## Writing custom storage adapter

  #### Example for WeChat 3rd-party Platform application

      defmodule MyComponentApp.Storage.Client do
        @behaviour WeChat.Storage.Client.Component

        @impl true
        def get_access_token(appid, authorizer_appid) do
          access_token = "Get authorizer's access_token by appid and authorizer_appid from your persistence..."
          access_token
        end

        @impl ture
        def get_component_access_token(appid) do
          access_token = "Get component access_token by component appid from your persistence..."
          access_token
        end

        @impl true
        def refresh_access_token(appid, authorizer_appid, access_token) do
          :ok
        end
      end
  """

  @doc """
  Get authorizer's access_token in WeChat component application.

  ## Example

      access_token_from_hub(appid, authorizer_appid)
  """
  @callback fetch_access_token(
              appid :: String.t(),
              authorizer_appid :: String.t()
            ) :: %WeChat.Token{} | nil | %WeChat.Error{}

  @doc """
  Get access_token of WeChat component application.

  ## Example

      component_access_token_from_hub(appid)
  """
  @callback fetch_component_access_token(appid :: String.t()) ::
              %WeChat.Token{} | nil | %WeChat.Error{}

  @doc """
  Refresh authorizer's access_token in WeChat component application.

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
              access_token :: String.t()
            ) :: String.t()

  @doc """
  Get authorizer's ticket in WeChat component application.

  ## Example

      fetch_ticket(appid, authorizer_appid, "wx_card")
      fetch_ticket(appid, authorizer_appid, "jsapi")
  """
  @callback fetch_ticket(appid :: String.t(), authorizer_appid :: String.t(), type :: String.t()) :: String.t() | nil | %WeChat.Error{}

end
