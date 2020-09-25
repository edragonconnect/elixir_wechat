defmodule WeChat.IntegrationTest do
  use ExUnit.Case

  @common_appid System.fetch_env!("TEST_COMMON_APPID")
  @test_openid System.fetch_env!("TEST_OPENID")

  test "user/info" do
    {:ok, response} = TestClient1.request(:get, url: "/cgi-bin/user/info", appid: @common_appid)

    # `openid` is required but missed.
    assert Map.get(response.body, "errcode") == 40003

    query = [
      openid: @test_openid
    ]

    {:ok, response} =
      TestClient1.request(:get,
        url: "/cgi-bin/user/info",
        appid: @common_appid,
        query: query
      )

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
end
