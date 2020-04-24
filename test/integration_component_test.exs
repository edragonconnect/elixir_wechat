defmodule WeChat.Component.IntegrationTest do
  use ExUnit.Case

  test "user/info" do
    {:ok, response} =
      TestComponentClient1.request(:get,
        url: "/cgi-bin/user/info",
        authorizer_appid: "wx6973a7470c360256"
      )

    # `openid` is required but missed.
    assert Map.get(response.body, "errcode") == 40003

    test_openid = "oRnWaxG1fWQOw164ED3x8Z40Wm00"

    query = [
      openid: test_openid
    ]

    {:ok, response} =
      TestComponentClient1.request(:get,
        url: "/cgi-bin/user/info",
        authorizer_appid: "wx6973a7470c360256",
        query: query
      )

    assert Map.get(response.body, "errcode") == nil
    assert Map.get(response.body, "openid") == test_openid

    {:ok, response} = TestComponentClient2.request(:get, url: "/cgi-bin/user/info", query: query)
    assert Map.get(response.body, "openid") == test_openid
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
        authorizer_appid: "wx6973a7470c360256"
      )

    assert Map.get(response.body, "media_id") != nil

    {:ok, response2} =
      TestComponentClient2.request(:post, url: "/cgi-bin/media/upload", body: {:form, body})

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
      TestComponentClient1.request(:post,
        url: "/cgi-bin/media/upload",
        body: {:form, body},
        authorizer_appid: "wx6973a7470c360256"
      )

    assert Map.get(response.body, "media_id") != nil

    {:ok, response2} =
      TestComponentClient2.request(:post, url: "/cgi-bin/media/upload", body: {:form, body})

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
      TestComponentClient1.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        authorizer_appid: "wx6973a7470c360256"
      )

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
        authorizer_appid: "wx6973a7470c360256"
      )

    assert response3.body == response.body

    {:error, error} =
      TestComponentClient2.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        authorizer_appid: "fake_authorizer_appid"
      )

    assert error.reason != nil

    body = %{
      type: "voice",
      offset: 0,
      count: 100
    }

    {:ok, response} =
      TestComponentClient1.request(:post,
        url: "/cgi-bin/material/batchget_material",
        body: body,
        authorizer_appid: "wx6973a7470c360256"
      )

    material_items = Map.get(response.body, "item")
    assert is_list(material_items) == true
  end
end
