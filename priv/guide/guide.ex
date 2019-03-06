defmodule GlobalAppIdClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat client and config with `appid` globally.
  
  This suite is for using `#{Mix.Project.config[:app]}` library in the Client side.

      defmodule WeChat.MyApp do
        use WeChat, appid: "MY_APPID"
      end

  Options:
  - `:appid`    - the appid of WeChat official account.
  - `:scenario`    - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token, 
                  using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key` and etc, when set scenario as `:client` by default, there will use
                         `WeChat.Storage.Default` by default, if need to override it for yourself, please implement required functions follow `WeChat.Adapter.Storage.Client`
                         behaviour module.

  """
  use WeChat, appid: "myappid"
end

defmodule DynamicAppIdClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat client without `appid` configuration, each time when invoke WeChat services need to input the `appid`.

  This suite is for using `#{Mix.Project.config[:app]}` library in the Server side, and can serve multiple WeChat official accounts dynamically.

      defmodule WeChat.MyApp do
        use WeChat
      end

  Options:
  - `:appid`    - the appid of WeChat official account.
  - `:scenario`     - the scenario of initialized client, options: `:hub` or `:client`, set as `:hub` option means it is self-manange access token in the hub, we need to
                  do it when using this library in the Server side, set as `:client` option means this library sends refresh request to the hub to fetch valid access token, 
                  using `:client` by default.
  - `:adapter_storage`    - the implements for some items persistence, e.g. `access_token`, `secret_key` and etc, when set scenario as `:client` by default, there will use
                         `WeChat.Storage.Default` by default, if need to override it for yourself, please implement required functions follow `WeChat.Adapter.Storage.Client`
                         behaviour module.
  """
  use WeChat
end

defmodule GlobalComponentAppIdClient do
  @moduledoc """
  NOTICE: THIS MODULE IS ONLY FOR DOCUMENT.

  Initialize a WeChat Component client and config with `component_appid` globally.
  
  This suite is for using `#{Mix.Project.config[:app]}` library in the Client side.

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

  Initialize a WeChat Component client without `component_appid` configuration, each time when invoke WeChat services need to input the `component_appid`.

  This suite is for using `#{Mix.Project.config[:app]}` library in the Server side, and can serve multiple WeChat 3rd-party platform applications dynamically.

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
