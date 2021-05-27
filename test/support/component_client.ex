defmodule TestComponentClient1 do
  use WeChat.Component,
    appid: System.fetch_env!("TEST_COMPONENT_APPID"),
    adapter_storage: {
      WeChat.Storage.Adapter.DefaultComponentClient,
      System.fetch_env!("TEST_HUB_URL")
    }
end

defmodule TestComponentClient2 do
  use WeChat.Component,
    appid: System.fetch_env!("TEST_COMPONENT_APPID"),
    authorizer_appid: System.fetch_env!("TEST_COMMON_APPID"),
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}
end

defmodule TestDynamicComponentClient do
  use WeChat.Component,
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}
end

defmodule CustomExpiresInComponentClient do
  use WeChat.Component,
    appid: System.fetch_env!("TEST_COMPONENT_APPID"),
    authorizer_appid: System.fetch_env!("TEST_COMMON_APPID"),
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}

  def expires_in(), do: 5000
end
