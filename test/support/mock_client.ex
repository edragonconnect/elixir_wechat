defmodule MockHub.TestAdapter.Common do
  @behaviour WeChat.Adapter.Storage.Hub

  require Logger

  @impl true
  def get_secret_key(_appid) do
    "secret_key"
  end

  @impl true
  def get_access_token(appid) do
    %WeChat.Token{access_token: "access_token_#{appid}"}
  end

  @impl true
  def save_access_token(_appid, _access_token) do
    :ok
  end

  @impl true
  def refresh_access_token(_appid, _access_token) do
    "refreshed_access_token"
  end

end

defmodule MockHub.TestAdapter.Component do

  @behaviour WeChat.Adapter.Storage.ComponentHub

  require Logger

  @impl true
  def get_secret_key(_appid) do
    "secret_key"
  end

  @impl true
  def get_access_token(appid, authorizer_appid) do
    %WeChat.Token{access_token: "access_token_#{appid}_#{authorizer_appid}"}
  end

  @impl true
  def save_access_token(_appid, _authorizer_appid, _access_token, _authorizer_refresh_token) do
    :ok
  end

  @impl true
  def refresh_access_token(_appid, _authorizer_appid, _access_token) do
    "refreshed_access_token"
  end

  @impl true
  def get_component_access_token(appid) do
    %WeChat.Token{access_token: "component_access_token_#{appid}"}
  end

  @impl true
  def save_component_access_token(_appid, _component_access_token) do
    :ok
  end

  @impl true
  def refresh_component_access_token(_appid, _component_access_token) do
    "refreshed_component_access_token"
  end

  @impl true
  def get_component_verify_ticket(_appid) do
    "component_verify_ticket"
  end

  @impl true
  def save_component_verify_ticket(_appid, _component_verify_ticket) do
    :ok
  end
end



defmodule MockComponentClient1 do
  use WeChat.Component, appid: "wx1b447daaec0c7110"
end

defmodule MockComponentClient2 do
  use WeChat.Component
end

defmodule MockCommonClient1 do
  use WeChat, appid: "wx02f6854d0cf042bb"
end

defmodule MockCommonClient2 do
  use WeChat
end

defmodule MockComponentHub1 do

  use WeChat.Component,
    appid: "wx1b447daaec0c7110",
    scenario: :hub,
    adapter_storage: MockHub.TestAdapter.Component

  def get_adapter_storage(), do: MockHub.TestAdapter.Component

end

defmodule MockCommonHub1 do
  use WeChat,
    appid: "CommonHub1Appid",
    scenario: :hub,
    adapter_storage: MockHub.TestAdapter.Common
  
  def get_adapter_storage(), do: MockHub.TestAdapter.Common
end

defmodule MockCommonHub2 do
  use WeChat,
    scenario: :hub,
    adapter_storage: MockHub.TestAdapter.Common
  
  def get_adapter_storage(), do: MockHub.TestAdapter.Common
end
