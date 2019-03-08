defmodule MockHub.Adapter.Common do
  @moduledoc false
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

defmodule MockHub.Adapter.Component do
  @moduledoc false
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

defmodule GlobalAppIdClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat client with `appid` globally.
  
  This suite is used for construct a Client to invoke WeChat APIs via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Client side.

      defmodule WeChat.MyApp do
        use WeChat, appid: "MY_APPID"
      end

  Options:
  - `:appid`    - the appid of WeChat official account.
  - `:scenario`    - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token, 
                  using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key` and etc, when set scenario as `:client` by default, there will use
                         `WeChat.Storage.Default` for adapter_storage, if need to override it for yourself, please implement required functions follow `WeChat.Adapter.Storage.Client`
                         behaviour module.

  """
  use WeChat, appid: "myappid"
end

defmodule DynamicAppIdClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat client without `appid`, each time when invoke WeChat services need to input the `appid` as a parameter.

  This suite is used for construct a Client to invoke WeChat APIs for serve multiple WeChat official accounts dynamically via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Client side.

      defmodule WeChat.MyApp do
        use WeChat
      end

  Options:
  - `:appid`    - the appid of WeChat official account.
  - `:scenario`     - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token, 
                  using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key` and etc, when set scenario as `:client` by default, there will use
                         `WeChat.Storage.Default` for adapter_storage, if need to override it for yourself, please implement required functions follow `WeChat.Adapter.Storage.Client`
                         behaviour module.
  """
  use WeChat
end

defmodule GlobalComponentAppIdClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat Component client with `component_appid` globally.
  
  This suite is used for construct a Client to invoke WeChat APIs via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Client side.

      defmodule WeChat.MyComponentApp do
        use WeChat.Component, appid: "MY_COMPONENT_APPID"
      end

  Options:
  - `:appid`    - the appid of WeChat 3rd-party platform application.
  - `:scenario`     - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token
                  of authorizer, using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key`, `component_access_token` and etc, when set scenario as `:client`
                         by default, there will use `WeChat.Storage.ComponentDefault` by default, if need to override it for yourself, please implement required functions follow
                         `WeChat.Adapter.Storage.ComponentClient` behaviour module.
  """
  use WeChat.Component, appid: "my_component_appid"
end

defmodule DynamicComponentAppIdClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat Component client without `component_appid`, each time when invoke WeChat services need to input the `component_appid` as a parameter.

  This suite is used for construct a Component Client to invoke WeChat APIs for serve multiple WeChat 3rd-party platform applications dynamically via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Client side.

      defmodule WeChat.MyComponentApp do
        use WeChat.Component
      end

  Options:
  - `:appid`    - the appid of WeChat 3rd-party platform application.
  - `:scenario`     - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch access token, 
                  using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key`, `component_access_token` and etc, when set scenario as `:client`
                         by default, there will use `WeChat.Storage.ComponentDefault` by default, if need to override it for yourself, please implement required functions follow
                         `WeChat.Adapter.Storage.ComponentClient` behaviour module.
  """
  use WeChat.Component
end

defmodule GlobalAppIdHubClient do

  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat client with `appid` globally.

  This suite is used for construct a Client to invoke WeChat APIs via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Server(`:hub` scenario) side.

      defmodule WeChat.MyApp do
        use WeChat,
          appid: "MY_APPID",
          scenario: :hub,
          adapter_storage: MockHub.Adapter.Common
      end

  `MockHub.Adapter.Common` is ONLY a sample module implemented `WeChat.Adapter.Storage.Hub`.

  Options:
  - `:appid`    - the appid of WeChat official account.
  - `:scenario`    - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token, 
                  using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key` and etc, when set scenario as `:hub`, this field option is required, 
                         please implement required functions follow `WeChat.Adapter.Storage.Hub` behaviour module.
  """
  use WeChat,
    appid: "myappid",
    scenario: :hub,
    adapter_storage: MockHub.Adapter.Common
end

defmodule DynamicAppIdHubClient do

  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat client without `appid`, each time when invoke WeChat services need to input the `appid` as a parameter.

  This suite is used for construct a Client to invoke WeChat APIs for serve multiple WeChat official accounts dynamically via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Server(`:hub` scenario) side.

      defmodule WeChat.MyApp do
        use WeChat,
          scenario: :hub,
          adapter_storage: MockHub.Adapter.Common
      end

  `MockHub.Adapter.Common` is ONLY a sample module implemented `WeChat.Adapter.Storage.Hub`.

  Options:
  - `:appid`    - the appid of WeChat official account.
  - `:scenario`     - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token, 
                  using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key` and etc, when set scenario as `:hub`, this field option is required, 
                         please implement required functions follow `WeChat.Adapter.Storage.Hub` behaviour module.
  """

  use WeChat,
    scenario: :hub,
    adapter_storage: MockHub.Adapter.Common
end


defmodule GlobalComponentAppIdHubClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat Component client with `component_appid` globally.

  This suite is used for construct a Client to invoke WeChat APIs via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Server(`:hub` scenario) side.

      defmodule WeChat.MyComponentApp do
        use WeChat.Component,
          appid: "MY_COMPONENT_APPID"
          scenario: :hub,
          adapter_storage: MockHub.Adapter.Component
      end

  `MockHub.Adapter.Component` is ONLY a sample module implemented `WeChat.Adapter.Storage.ComponentHub`.

  Options:
  - `:appid`    - the appid of WeChat 3rd-party platform application.
  - `:scenario`     - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token
                  of authorizer, using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key`, `component_access_token` and etc, when set scenario as `:hub`, this field
                        option is required, please implement required functions follow `WeChat.Adapter.Storage.ComponentHub`.
  """
  use WeChat.Component,
    appid: "my_component_appid",
    scenario: :hub,
    adapter_storage: MockHub.Adapter.Component
end

defmodule DynamicComponentAppIdHubClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat Component client without `component_appid`, each time when invoke WeChat services need to input the `component_appid`.

  This suite is used for construct a Component Client to invoke WeChat APIs for serve multiple WeChat 3rd-party platform applications dynamically via `#{Mix.Project.config[:app]}` library, this usecase is usual for the Server(`:hub` scenario) side.

      defmodule WeChat.MyComponentApp do
        use WeChat.Component
          scenario: :hub,
          adapter_storage: MockHub.Adapter.Component
      end

  `MockHub.Adapter.Component` is ONLY a sample module implemented `WeChat.Adapter.Storage.ComponentHub`.

  Options:
  - `:appid`    - the appid of WeChat 3rd-party platform application.
  - `:scenario`     - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch access token, using 
                  `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key`, `component_access_token` and etc, when set scenario as `:hub`, this field
                        option is required, please implement required functions follow `WeChat.Adapter.Storage.ComponentHub`.
  """
  use WeChat.Component,
    scenario: :hub,
    adapter_storage: MockHub.Adapter.Component
end
