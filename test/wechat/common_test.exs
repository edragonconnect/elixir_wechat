defmodule WeChat.CommonTest do
  use ExUnit.Case

  import Mock

  test "no defined :token functions when use this function in common client, prohibit refresh authorizer access_token in the client scenario" do
    assert function_exported?(MockCommonClient1, :token, 1) == false
    assert function_exported?(MockCommonClient1, :token, 2) == false
    assert function_exported?(MockCommonClient1, :token, 3) == false

    assert function_exported?(MockCommonClient2, :token, 2) == false
    assert function_exported?(MockCommonClient2, :token, 3) == false
    assert function_exported?(MockCommonClient2, :token, 4) == false

  end

  test "defined :token function when use this function in common client, provide a way to refresh self access_token in the hub scenario" do
    Code.ensure_loaded MockCommonHub1
    assert function_exported?(MockCommonHub1, :token, 1) == true
    assert function_exported?(MockCommonHub1, :token, 2) == true
    assert function_exported?(MockCommonHub1, :token, 3) == true

    Code.ensure_loaded MockCommonHub2
    assert function_exported?(MockCommonHub2, :token, 2) == true
    assert function_exported?(MockCommonHub2, :token, 3) == true
    assert function_exported?(MockCommonHub2, :token, 4) == true
  end

  test "get access_token from remote hub in the client scenario" do
    with_mocks([
      {WeChat.Storage.Default, [], [get_access_token: fn(_appid) -> %WeChat.Token{access_token: "mock_access_token"} end]}
    ]) do
      access_token = MockCommonClient1.get_access_token()
      assert access_token == "mock_access_token"
    end
    
    with_mocks([
      {WeChat.Storage.Default, [], [get_access_token: fn(appid) -> %WeChat.Token{access_token: "mock_access_token_#{appid}"} end]}
    ]) do
      appid = "appid123"
      access_token = MockCommonClient2.get_access_token(appid)
      assert access_token == "mock_access_token_#{appid}"
    end
  end

  test "get access_token from local as the hub scenario" do
    appid = "CommonHub1Appid"
    adapter_storage = MockCommonHub1.get_adapter_storage
    access_token = MockCommonHub1.get_access_token()

    token_from_adapter = adapter_storage.get_access_token(appid)
    assert access_token == token_from_adapter.access_token

    hub2_adapter_storage = MockCommonHub2.get_adapter_storage
    hub2_token_from_adapter = hub2_adapter_storage.get_access_token(appid)
    hub2_access_token = MockCommonHub2.get_access_token(appid)
    assert hub2_access_token == hub2_token_from_adapter.access_token
  end

  test "wechat api function - get materialcount" do
    appid = "wx02f6854d0cf042bb"
    result = MockCommonClient1.material(:get, :get_materialcount)
    case result do
      {:ok, response} ->
        assert response.status == 200
        assert response.body != nil
        {:ok, response2} = MockCommonClient2.material(:get, appid, :get_materialcount)
        assert response2.status == 200
        # Most of the time, the query data should be the same between two consecutive requests
        assert response2.body == response.body
      {:error, error} ->
        IO.puts "client invoke get_materialcount occur error: #{inspect error}"
    end
  end

  test "wechat api function - post batchget_material" do
    appid = "wx02f6854d0cf042bb"
    request_data = %{
      type: "news",
      offset: 0,
      count: 1
    }
    result = MockCommonClient1.material(:post, :batchget_material, request_data)
    case result do
      {:ok, response} ->
        assert response.status == 200
        assert response.body != nil
        # `request_data` as following map struct is available as well.
        request_data = %{
          "type" => "news",
          "offset" => 0,
          "count" => 1
        }
        {:ok, response2} = MockCommonClient2.material(:post, appid, :batchget_material, request_data)
        assert response2.status == 200
        assert response2.body == response.body
      {:error, error} ->
        IO.puts "client invoke batchget_material occur error: #{inspect error}"
    end
  end

  test "wechat api function - upload media" do
    file_path = Path.join(Path.dirname(__DIR__), "data/elixir_logo.png")
    media = %WeChat.UploadMedia{
      file_path: file_path,
      type: "image"
    }
    result = MockCommonClient1.media(:post_form, :upload, %{media: media})
    case result do
      {:ok, response} ->
        assert response.status == 200
        media_id1 = Map.get(response.body, "media_id")
        assert media_id1 != nil

        # test appid
        appid = "wx02f6854d0cf042bb"
        fc = File.read!(file_path)
        media = %WeChat.UploadMediaContent{
         file_content: fc,
         file_name: "elixir_logo.png",
         type: "image"
        }
        {:ok, response2} = MockCommonClient2.media(:post_form, appid, :upload, %{media: media})
        assert response2.status == 200
        media_id2 = Map.get(response2.body, "media_id")
        assert media_id2 != nil and media_id1 != media_id2

      {:error, error} ->
        IO.puts "client occurs error when upload media: #{inspect error}"
    end
  end

  test "mock refresh access token" do
    with_mock Tesla, [:passthrough], [run: fn(env, _next) ->
        if env.url == "https://api.weixin.qq.com/cgi-bin/material/get_materialcount" do
          case Enum.random(0..10) do
            0 ->
              {:ok,
                %{
                  status: 200,
                  headers: [],
                  body: "{\"data\":[],\"errcode\":0}",
                  query: [],
                  url: env.url
                }
              }
            _ ->
              {
                :ok,
                %{
                  status: 200,
                  headers: [],
                  body: "{\"errcode\":40001}",
                  query: [],
                  url: env.url
                }
              }
          end
        else
          {
            :ok,
            %{
              status: 200,
              headers: [],
              body: %{"access_token" => "invalid"}
            }
          }
        end
      end] do
      appid = "wx02f6854d0cf042bb"
      {:ok, response} = MockCommonClient2.material(:get, appid, :get_materialcount)
      assert Map.get(response.body, "data") == []

      {:ok, response2} = MockCommonClient1.material(:get, :get_materialcount)
      assert Map.get(response2.body, "data") == []
    end
  end

end
