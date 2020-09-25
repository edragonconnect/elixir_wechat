defmodule TestClient1 do
  use WeChat,
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}
end

defmodule TestClient2 do
  use WeChat,
    appid: System.fetch_env!("TEST_COMMON_APPID"),
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}
end
