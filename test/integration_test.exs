defmodule WeChat.IntegrationTest do
  use ExUnit.Case

  @common_appid System.fetch_env!("TEST_COMMON_APPID")
  @test_openid System.fetch_env!("TEST_OPENID")

  defp get_user_info(openid \\ @test_openid) do
    query = [openid: openid]

    {:ok, response} =
      TestClient1.request(:get,
        url: "/cgi-bin/user/info",
        appid: @common_appid,
        query: query
      )

    response
  end

  defp get_jsapi_ticket() do
    {:ok, response} =
      TestClient1.request(:get,
        url: "/cgi-bin/ticket/getticket",
        appid: @common_appid,
        query: [type: "jsapi"]
      )
    response
  end

  test "user/info" do
    {:ok, response} = TestClient1.request(:get, url: "/cgi-bin/user/info", appid: @common_appid)

    # `openid` is required but missed.
    assert Map.get(response.body, "errcode") == 40003

    query = [
      openid: @test_openid
    ]

    response = get_user_info()

    assert Map.get(response.body, "errcode") == nil
    assert Map.get(response.body, "openid") == @test_openid

    {:ok, response} = TestClient2.request(:get, url: "/cgi-bin/user/info", query: query)
    assert Map.get(response.body, "openid") == @test_openid
  end

  test "media/upload - file" do
    file_path = Path.join(Path.dirname(__DIR__), "/test/data/elixir_logo.png")

    media = %WeChat.UploadMedia{
      file_path: file_path,
      type: "image"
    }

    body = %{media: media}

    {:ok, response} =
      TestClient1.request(:post,
        url: "/cgi-bin/media/upload",
        body: {:form, body},
        appid: @common_appid
      )

    assert Map.get(response.body, "media_id") != nil

    {:ok, response2} =
      TestClient2.request(:post, url: "/cgi-bin/media/upload", body: {:form, body})

    assert Map.get(response2.body, "media_id") != nil
  end

  test "media/upload - content" do
    file_path = Path.join(Path.dirname(__DIR__), "/test/data/elixir_logo.png")
    file_content = File.read!(file_path)

    media = %WeChat.UploadMediaContent{
      file_content: file_content,
      file_name: "elixir_logo.png",
      type: "image"
    }

    body = %{media: media}

    {:ok, response} =
      TestClient1.request(:post,
        url: "/cgi-bin/media/upload",
        body: {:form, body},
        appid: @common_appid
      )

    assert Map.get(response.body, "media_id") != nil

    {:ok, response2} =
      TestClient2.request(:post, url: "/cgi-bin/media/upload", body: {:form, body})

    assert Map.get(response2.body, "media_id") != nil
  end

  test "batchget_material" do
    batchget_size = 2

    body = %{
      "type" => "image",
      "offset" => 0,
      "count" => batchget_size
    }

    {:ok, response} =
      TestClient1.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        appid: @common_appid
      )

    material_items = Map.get(response.body, "item")
    assert is_list(material_items) == true
    assert length(material_items) <= batchget_size

    {:ok, response2} =
      TestClient2.request(:post, url: "/cgi-bin/material/batchget_material", body: body)

    assert response2.body == response.body

    # `authorizer_appid` can be override when dynamically send request
    {:ok, response3} =
      TestClient2.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        appid: @common_appid
      )

    assert response3.body == response.body

    {:error, error} =
      TestClient2.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        appid: "fake_authorizer_appid"
      )

    # invalid appid response from WeChat server side
    assert error.errcode == 40013

    body = %{
      type: "voice",
      offset: 0,
      count: 100
    }

    {:ok, response} =
      TestClient1.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        appid: @common_appid
      )

    material_items = Map.get(response.body, "item")
    assert is_list(material_items) == true
  end

  test "make access_token invalid/expired in local registry" do
    response = get_user_info()

    errcode = Map.get(response.body, "errcode")

    if errcode == nil do
      registry_key = "access_token.#{@common_appid}"

      token = WeChat.Registry.read_from_local(:fetch_access_token, [@common_appid, ""])

      assert token.access_token != nil and token.timestamp != nil and token.expires_in != nil

      # manual set the local access_token as invalid
      {_updated, _} = Registry.update_value(WeChat.Registry, registry_key, fn (value) -> Map.put(value, :access_token, "invalid_access_token") end)

      # call call a detailed function with local invalid access_token
      response = get_user_info()

      errcode = Map.get(response.body, "errcode")

      if errcode == nil do
        # expected to work
        assert Map.get(response.body, "openid") == @test_openid

        token = WeChat.Registry.read_from_local(:fetch_access_token, [@common_appid, ""])

        assert token.access_token != nil and token.timestamp != nil and token.expires_in != nil
      end

      # manual set the local access_token as expired
      {_updated, _} = Registry.update_value(WeChat.Registry, registry_key, fn (value) -> Map.put(value, :timestamp, 0) end)

      # call call a detailed function with local expired access_token
      response = get_user_info()

      errcode = Map.get(response.body, "errcode")

      if errcode == nil do
        # expected to work
        assert Map.get(response.body, "openid") == @test_openid

        token = WeChat.Registry.read_from_local(:fetch_access_token, [@common_appid, ""])

        assert token.access_token != nil and token.timestamp != nil and token.expires_in != nil
      end
    end

  end

  test "ticket in local registry" do
    response = get_jsapi_ticket()

    %WeChat.Ticket{value: value, timestamp: timestamp, expires_in: expires_in} = WeChat.Registry.read_from_local(:fetch_ticket, [@common_appid, "jsapi", ""])

    assert Map.get(response.body, "ticket") == value
    assert Map.get(response.body, "timestamp") == timestamp
    assert Map.get(response.body, "expires_in") == expires_in

    registry_key = "ticket.#{@common_appid}.jsapi"

    # manual set the local jsapid ticket as expired
    {_updated, _} = Registry.update_value(WeChat.Registry, registry_key, fn (value) -> Map.put(value, :timestamp, 0) end)

    # recall ticket althought the local ticket registry is expired
    response = get_jsapi_ticket()

    # after the above api recall remotely, will reset the local ticket registry
    %WeChat.Ticket{value: value, timestamp: timestamp, expires_in: expires_in} = WeChat.Registry.read_from_local(:fetch_ticket, [@common_appid, "jsapi", ""])

    assert Map.get(response.body, "ticket") == value
    assert Map.get(response.body, "timestamp") == timestamp
    assert Map.get(response.body, "expires_in") == expires_in
  end
end
