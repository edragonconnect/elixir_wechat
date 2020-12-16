defmodule TestClient1 do
  use WeChat,
    adapter_storage: {
      WeChat.Storage.Adapter.DefaultClient,
      System.fetch_env!("TEST_HUB_URL")
    }
end

defmodule TestClient2 do
  use WeChat,
    appid: System.fetch_env!("TEST_COMMON_APPID"),
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}
end

defmodule CustomExpiresInClient do
  use WeChat,
    appid: System.fetch_env!("TEST_COMMON_APPID"),
    adapter_storage: {:default, System.fetch_env!("TEST_HUB_URL")}

  def expires_in(), do: 6000
end
