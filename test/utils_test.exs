defmodule WeChat.UtilsTest do
  use ExUnit.Case

  alias WeChat.Utils

  test "parse_uri" do
    uri = Utils.parse_uri("https://api.weixin.qq.com/cgi-bin/user/info/batchget")

    assert uri.scheme == "https" and uri.port == 443 and uri.host == "api.weixin.qq.com" and
             uri.path == "/cgi-bin/user/info/batchget"

    uri = Utils.parse_uri("//cgi-bin/user/info/batchget")

    assert uri.scheme == "https" and uri.port == 443 and uri.host == "cgi-bin" and
             uri.path == "/user/info/batchget"

    uri = Utils.parse_uri("cgi-bin/user/info/batchget")

    assert uri.scheme == "https" and uri.port == 443 and uri.host == "api.weixin.qq.com" and
             uri.path == "cgi-bin/user/info/batchget"

    uri = Utils.parse_uri("/a/b", host: "test.api.weixin.qq.com", port: 443)

    assert uri.scheme == "https" and uri.port == 443 and uri.host == "test.api.weixin.qq.com" and
             uri.path == "/a/b"

    uri = Utils.parse_uri("/a/b?arg1=1")
    assert uri.path == "/a/b" and uri.query == "arg1=1"

    uri = Utils.parse_uri("/a/b?arg1=1", port: 80, scheme: "http")

    assert uri.path == "/a/b" and uri.query == "arg1=1" and uri.port == 80 and
             uri.scheme == "http"

    uri = Utils.parse_uri("/a/b?arg1=1")
    assert uri.path == "/a/b" and uri.query == "arg1=1"

    uri = Utils.parse_uri("/a/b?arg1=1&name=name1")
    assert uri.path == "/a/b" and uri.query == "arg1=1&name=name1"

    uri = Utils.parse_uri(nil)
    assert uri == nil
  end

  test "merge_keyword" do
    result = Utils.merge_keyword([name: 1], name: "new", age: 2)
    assert result[:name] == 1 and result[:age] == 2
    result = Utils.merge_keyword([name: nil], name: "new", age: 2)
    assert result[:name] == "new" and result[:age] == 2
    result = Utils.merge_keyword([name: 1], name2: "new", age: 2)
    assert result[:name] == 1 and result[:name2] == "new" and result[:age] == 2
  end

  test "json_decode" do
    assert Utils.json_decode("") == nil
    assert Utils.json_decode(nil) == nil
    assert Utils.json_decode("[1, 2, 3]") == [1, 2, 3]
    result = Utils.json_decode("{\"k1\":1,\"k2\":\"v2\"}")
    assert Map.get(result, "k1") == 1 and Map.get(result, "k2") == "v2"
  end
end
