defmodule TestComponentClient1 do
  use WeChat.Component,
    appid: System.fetch_env!("TEST_COMPONENT_APPID"),
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}
end

defmodule TestComponentClient2 do
  use WeChat.Component,
    appid: System.fetch_env!("TEST_COMPONENT_APPID"),
    authorizer_appid: System.fetch_env!("TEST_COMMON_APPID"),
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}
end
