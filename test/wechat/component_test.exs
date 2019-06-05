defmodule WeChat.ComponentTest do
  use ExUnit.Case

  import Mock

  test "invalid usecase - call component/api_component_token as component client" do
    assert_raise RuntimeError, ~r/Invalid usecase, set uri_supplement as :api_component_token is ignored when invoke function `component` in the client scenario./, fn ->
      MockComponentClient1.component(:post, :api_component_token, %{})
    end

    assert_raise RuntimeError, ~r/Invalid usecase, set uri_supplement as :api_component_token is ignored when invoke function `component` in the client scenario./, fn ->
      MockComponentClient2.component(:post, "fakeappid", :api_component_token, %{})
    end
  end

  test "no defined :token functions when use this function in component client, prohibit refresh authorizer access_token in the client scenario" do
    assert function_exported?(MockComponentClient1, :token, 1) == false
    assert function_exported?(MockComponentClient1, :token, 2) == false
    assert function_exported?(MockComponentClient1, :token, 3) == false

    assert function_exported?(MockComponentClient2, :token, 2) == false
    assert function_exported?(MockComponentClient2, :token, 3) == false
    assert function_exported?(MockComponentClient2, :token, 4) == false

    assert function_exported?(MockComponentHub1, :token, 1) == false
    assert function_exported?(MockComponentHub1, :token, 2) == false
    assert function_exported?(MockComponentHub1, :token, 3) == false
  end

  test "get component_access_token from remote hub in the client scenario" do
    with_mocks([
      {WeChat.Storage.ComponentDefault, [], [get_component_access_token: fn(_appid) -> %WeChat.Token{access_token: "mock_component_access_token"} end]}
    ]) do
      component_access_token = MockComponentClient1.get_component_access_token()
      assert component_access_token == "mock_component_access_token"
    end
    
    with_mocks([
      {WeChat.Storage.ComponentDefault, [], [get_component_access_token: fn(appid) -> %WeChat.Token{access_token: "mock_component_access_token_#{appid}"} end]}
    ]) do
      component_access_token = MockComponentClient2.get_component_access_token("appid123")
      assert component_access_token == "mock_component_access_token_appid123"
    end
  end

  test "get authorizer access_token from remote hub in the client scenario" do
    fake_component_appid = "appid123"
    fake_authorizer_appid = "fake_authorizer_appid"
    with_mocks([
      {WeChat.Storage.ComponentDefault, [], [get_access_token: fn(_appid, authorizer_appid) -> %WeChat.Token{access_token: "mock_access_token_#{authorizer_appid}"} end]}
    ]) do
      component_access_token = MockComponentClient1.get_access_token(fake_authorizer_appid)
      assert component_access_token == "mock_access_token_#{fake_authorizer_appid}"
    end

    with_mocks([
      {WeChat.Storage.ComponentDefault, [], [get_access_token: fn(appid, authorizer_appid) -> %WeChat.Token{access_token: "mock_access_token_#{appid}_#{authorizer_appid}"} end]}
    ]) do
      component_access_token = MockComponentClient2.get_access_token(fake_component_appid, fake_authorizer_appid)
      assert component_access_token == "mock_access_token_#{fake_component_appid}_#{fake_authorizer_appid}"
    end
  end

  test "get component_access_token from local as the hub scenario" do
    fake_component_appid = "wx1b447daaec0c7110"
    fake_authorizer_appid = "fake_authorizer_appid"
    adapter_storage = MockComponentHub1.get_adapter_storage
    access_token = MockComponentHub1.get_access_token(fake_authorizer_appid)

    token_from_adapter = adapter_storage.get_access_token(fake_component_appid, fake_authorizer_appid)
    assert access_token == token_from_adapter.access_token
  end

  test "wechat api function - get materialcount" do
    component_appid = "wx1b447daaec0c7110"
    authorizer_appid = "wx6973a7470c360256"
    result = MockComponentClient1.material(:get, authorizer_appid, :get_materialcount)
    case result do
      {:ok, response} ->
        assert response.status == 200
        assert response.body != nil
        {:ok, response2} = MockComponentClient2.material(:get, component_appid, authorizer_appid, :get_materialcount)
        assert response2.status == 200
        # Most of the time, the query data should be the same between two consecutive requests
        assert response2.body == response.body
      {:error, error} ->
        IO.puts "client invoke get_materialcount occur error: #{inspect error}"
    end
  end

  test "wechat api function - get media" do
    authorizer_appid = "wx6973a7470c360256"
    media_id = "dsg-_SKNmxSnxPYVlI9RIQsrUXyZ_lkgc5M2KoabL9NsM9JNhNi4TxrsYQs6ugu1"
    {:ok, response} = MockComponentClient1.media(:get, authorizer_appid, :get, media_id: media_id)
    assert is_binary(response.body) == true
  end

  test "wechat api function - post batchget_material" do
    component_appid = "wx1b447daaec0c7110"
    authorizer_appid = "wx6973a7470c360256"
    request_data = %{
      type: "news",
      offset: 0,
      count: 1
    }
    result = MockComponentClient1.material(:post, authorizer_appid, :batchget_material, request_data)
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
        {:ok, response2} = MockComponentClient2.material(:post, component_appid, authorizer_appid, :batchget_material, request_data)
        assert response2.status == 200
        assert response2.body == response.body
      {:error, error} ->
        IO.puts "client invoke batchget_material occur error: #{inspect error}"
    end
  end

  test "mock refresh authorizer access token" do
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
      appid = "wx1b447daaec0c7110"
      authorizer_appid = "wx6973a7470c360256"
      {:ok, response} = MockComponentClient1.material(:get, authorizer_appid, :get_materialcount)
      assert Map.get(response.body, "data") == []

      {:ok, response2} = MockComponentClient2.material(:get, appid, authorizer_appid, :get_materialcount)
      assert Map.get(response2.body, "data") == []
    end
  end

  test "mock refresh component access token" do
    with_mock Tesla, [:passthrough], [run: fn(env, _next) ->
        if env.url == "https://api.weixin.qq.com/cgi-bin/component/api_create_preauthcode" do
          case Enum.random(0..10) do
            0 ->
              {:ok,
                %{
                  status: 200,
                  headers: [],
                  body: "{\"data\":[1,2,3],\"errcode\":0}",
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
      appid = "wx1b447daaec0c7110"
      data = %{
        "component_appid" => appid
      }
      {:ok, response} = MockComponentHub1.component(:post, :api_create_preauthcode, data)
      assert Map.get(response.body, "data") == [1, 2, 3]

      {:ok, response2} = MockComponentHub2.component(:post, appid, :api_create_preauthcode, data)
      assert Map.get(response2.body, "data") == [1, 2, 3]
    end
  end

end
