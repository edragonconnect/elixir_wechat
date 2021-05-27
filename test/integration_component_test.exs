defmodule WeChat.Component.IntegrationTest do
  use ExUnit.Case

  @component_appid System.fetch_env!("TEST_COMPONENT_APPID")
  @authorizer_appid System.fetch_env!("TEST_COMMON_APPID")
  @test_openid System.fetch_env!("TEST_OPENID")

  defp get_user_info(openid \\ @test_openid) do
    {:ok, response} =
      TestComponentClient1.request(:get,
        url: "/cgi-bin/user/info",
        authorizer_appid: @authorizer_appid,
        query: [openid: openid]
      )
    response
  end

  defp get_jsapi_ticket() do
    {:ok, response} =
      TestComponentClient1.request(:get,
        url: "/cgi-bin/ticket/getticket",
        authorizer_appid: @authorizer_appid,
        query: [type: "jsapi"]
      )
    response
  end

  defp component_get_authorizer_list() do
    # call this function should cache `component_access_token` in
    # local registry
    {:ok, response} =
      TestComponentClient1.request(:post,
        url: "/cgi-bin/component/api_get_authorizer_list",
        body: %{offset: 0, count: 100}
      )
    response
  end

  test "user/info" do
    {:ok, response} =
      TestComponentClient1.request(:get,
        url: "/cgi-bin/user/info",
        authorizer_appid: @authorizer_appid
      )

    # `openid` is required but missed, or clientip is not in the ip whitelist
    errcode = Map.get(response.body, "errcode")
    assert errcode == 40003 or errcode == 61004

    query = [
      openid: @test_openid
    ]

    response = get_user_info()

    errcode = Map.get(response.body, "errcode")

    if errcode == nil do
      assert Map.get(response.body, "openid") == @test_openid
    else
      # clientip not in the ip whitelist
      assert errcode == 61004
    end

    {:ok, response} = TestComponentClient2.request(:get, url: "/cgi-bin/user/info", query: query)

    errcode = Map.get(response.body, "errcode")

    if errcode == nil do
      assert Map.get(response.body, "openid") == @test_openid
    end
  end

  test "media/upload - file" do
    file_path = Path.join(Path.dirname(__DIR__), "/test/data/elixir_logo.png")

    media = %WeChat.UploadMedia{
      file_path: file_path,
      type: "image"
    }

    body = %{media: media}

    {:ok, response} =
      TestComponentClient1.request(:post,
        url: "/cgi-bin/media/upload",
        body: {:form, body},
        authorizer_appid: @authorizer_appid
      )

    errcode = Map.get(response.body, "errcode")

    if errcode == nil do
      assert Map.get(response.body, "media_id") != nil

      {:ok, response2} =
        TestComponentClient2.request(:post, url: "/cgi-bin/media/upload", body: {:form, body})

      assert Map.get(response2.body, "media_id") != nil
    end
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
      TestComponentClient1.request(:post,
        url: "/cgi-bin/media/upload",
        body: {:form, body},
        authorizer_appid: @authorizer_appid
      )

    errcode = Map.get(response.body, "errcode")

    if errcode == nil do
      assert Map.get(response.body, "media_id") != nil

      {:ok, response2} =
        TestComponentClient2.request(:post, url: "/cgi-bin/media/upload", body: {:form, body})

      assert Map.get(response2.body, "media_id") != nil
    end
  end

  test "batchget_material" do
    batchget_size = 2

    body = %{
      "type" => "image",
      "offset" => 0,
      "count" => batchget_size
    }

    {:ok, response} =
      TestComponentClient1.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        authorizer_appid: @authorizer_appid
      )

    errcode = Map.get(response.body, "errcode")

    if errcode == nil do
      material_items = Map.get(response.body, "item")
      assert is_list(material_items) == true
      assert length(material_items) <= batchget_size

      {:ok, response2} =
        TestComponentClient2.request(:post, url: "/cgi-bin/material/batchget_material", body: body)

      assert response2.body == response.body

      # `authorizer_appid` can be override when dynamically send request
      {:ok, response3} =
        TestComponentClient2.request(:post,
          url: "/cgi-bin/material/batchget_material",
          body: body,
          authorizer_appid: @authorizer_appid
        )

      assert response3.body == response.body

      {:error, error} =
        TestComponentClient2.request(:post,
          url: "/cgi-bin/material/batchget_material",
          body: body,
          authorizer_appid: "fake_authorizer_appid"
        )

      assert error.reason == "invalid_authorizer_appid"

      body = %{
        type: "voice",
        offset: 0,
        count: 100
      }

      {:ok, response} =
        TestComponentClient1.request(:post,
          url: "/cgi-bin/material/batchget_material",
          body: body,
          authorizer_appid: @authorizer_appid
        )

      material_items = Map.get(response.body, "item")
      assert is_list(material_items) == true
    end
  end

  test "make access_token invalid/expired in local registry" do
    response = get_user_info()

    errcode = Map.get(response.body, "errcode")

    registry_key = "access_token.#{@component_appid}.#{@authorizer_appid}"

    if errcode == nil do
      assert Map.get(response.body, "openid") == @test_openid

      token = WeChat.Registry.read_from_local(:fetch_access_token, [@component_appid, @authorizer_appid, ""])
      assert token.access_token != nil

      # manual set the local access_token as invalid
      :ets.insert(WeChat.Registry, {registry_key, Map.put(token, :access_token, "invalid_access_token")})

      # call a detailed function with local invalid access_token
      response = get_user_info()

      errcode = Map.get(response.body, "errcode")

      if errcode == nil do
        # expected to work
        assert Map.get(response.body, "openid") == @test_openid

        # and the local access_token is reset now
        token = WeChat.Registry.read_from_local(:fetch_access_token, [@component_appid, @authorizer_appid, ""])
        assert token.access_token != nil and token.timestamp != nil and token.expires_in != nil
      end

      # manual set the local access_token as expired
      :ets.insert(WeChat.Registry, {registry_key, Map.put(token, :timestamp, 0)})

      # call a detailed function with local expired access_token
      response = get_user_info()

      errcode = Map.get(response.body, "errcode")

      if errcode == nil do
        # expected to work
        assert Map.get(response.body, "openid") == @test_openid

        # and the local access_token is reset now
        token = WeChat.Registry.read_from_local(:fetch_access_token, [@component_appid, @authorizer_appid, ""])
        assert token.access_token != nil and token.timestamp != nil and token.expires_in != nil
      end
    end

  end

  test "ticket in local registry" do
    response = get_jsapi_ticket()

    ticket = WeChat.Registry.read_from_local(:fetch_ticket, [@component_appid, @authorizer_appid, "jsapi", ""])

    %WeChat.Ticket{value: value, timestamp: timestamp, expires_in: expires_in} = ticket

    assert Map.get(response.body, "ticket") == value
    assert Map.get(response.body, "timestamp") == timestamp
    assert Map.get(response.body, "expires_in") == expires_in

    registry_key = "ticket.#{@component_appid}.#{@authorizer_appid}.jsapi"

    # manual set the local jsapid ticket as expired
    :ets.insert(WeChat.Registry, {registry_key, Map.put(ticket, :timestamp, 0)})

    # recall ticket althought the local ticket registry is expired
    response = get_jsapi_ticket()

    # after the above api recall remotely, will reset the local ticket registry
    %WeChat.Ticket{value: value, timestamp: timestamp, expires_in: expires_in} = WeChat.Registry.read_from_local(:fetch_ticket, [@component_appid, @authorizer_appid, "jsapi", ""])

    assert Map.get(response.body, "ticket") == value
    assert Map.get(response.body, "timestamp") == timestamp
    assert Map.get(response.body, "expires_in") == expires_in
  end

  test "component access_token in local registry" do
    response = component_get_authorizer_list()
    assert Map.get(response.body, "list") != nil

    registry_key = "component_access_token.#{@component_appid}"

    token = WeChat.Registry.read_from_local(:fetch_component_access_token, [@component_appid, ""])
    assert token.access_token != nil and token.timestamp != nil and token.expires_in != nil

    # manual set the local component access_token as expired.
    # currently, since the `component_access_token` is maintained(cover refresh) in hub scenario,
    # make `component_access_token` as invalid in client scenario is out of scope,
    # we can test this case in hub scenario
    :ets.insert(WeChat.Registry, {registry_key, Map.put(token, :timestamp, 0)})

    response = component_get_authorizer_list()
    assert Map.get(response.body, "list") != nil

    token = WeChat.Registry.read_from_local(:fetch_component_access_token, [@component_appid, ""])
    assert token.access_token != nil and token.timestamp != nil and token.expires_in != nil
  end

  test "component fetch oauth2 access_token by invalid info" do
    {:ok, response} =
      TestDynamicComponentClient.request(
        :get,
        url: "/sns/oauth2/component/access_token",
        query: [
          appid: "fake_authorizer_appid",
          component_appid: @component_appid,
          code: "invalid_code",
          grant_type: "authorization_code"
        ]
      )
    assert response.body["errcode"] == 40013 and
             response.body["errmsg"] =~ ~s/invalid appid/
  end
end
