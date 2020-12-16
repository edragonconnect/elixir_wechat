defmodule WeChat.RegistryTest do
  use ExUnit.Case, async: false

  alias WeChat.{Registry, Utils}

  test "fetch_access_token" do
    # component client
    #
    {key, item} = Registry.read_from_local(:fetch_access_token, ["appid", "authorizer_appid", ""])
    assert item == nil
    data = %WeChat.Token{access_token: "componentapp_access_token", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    # expect write_to_local/2 the data in {:ok, _} format
    Registry.write_to_local(key, data)
    {_key, item} = Registry.read_from_local(:fetch_access_token, ["appid", "authorizer_appid", ""])
    assert item == nil

    Registry.write_to_local(key, {:ok, data})
    assert Registry.read_from_local(:fetch_access_token, ["appid", "authorizer_appid", ""]) == data

    # common client
    #
    {key, item} = Registry.read_from_local(:fetch_access_token, ["appid", ""])
    assert item == nil
    data = %WeChat.Token{access_token: "commonapp_access_token", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    Registry.write_to_local(key, {:ok, data})
    assert Registry.read_from_local(:fetch_access_token, ["appid", ""]) == data
  end

  test "fetch_ticket" do
    # component client
    #
    {key, item} = Registry.read_from_local(:fetch_ticket, ["appid", "authorizer_appid", "tickettype", ""])
    assert item == nil
    data = %WeChat.Ticket{value: "componentapp_ticket", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    Registry.write_to_local(key, {:ok, data})
    assert Registry.read_from_local(:fetch_ticket, ["appid", "authorizer_appid", "tickettype", ""]) == data

    # common client
    #
    {key, item} = Registry.read_from_local(:fetch_ticket, ["appid", "tickettype", ""])
    assert item == nil
    data = %WeChat.Ticket{value: "commonapp_ticket", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    Registry.write_to_local(key, {:ok, data})
    assert Registry.read_from_local(:fetch_ticket, ["appid", "tickettype", ""]) == data
  end

  test "refresh_access_token" do
    # component client
    #
    {key, item} = Registry.read_from_local(:refresh_access_token, ["appid", "authorizer_appid", "fake_access_token", ""])
    assert item == nil

    data = %WeChat.Token{access_token: "fake_access_token", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    Registry.write_to_local(key, {:ok, data})

    # once refresh access_token will always clean local registry
    {^key, item} = Registry.read_from_local(:refresh_access_token, ["appid", "authorizer_appid", "fake_access_token", ""])
    assert item == nil

    # common client
    {key, item} = Registry.read_from_local(:refresh_access_token, ["appid", "fake_access_token", ""])
    assert item == nil

    data = %WeChat.Token{access_token: "fake_access_token", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    Registry.write_to_local(key, {:ok, data})

    {^key, item} = Registry.read_from_local(:refresh_access_token, ["appid", "fake_access_token", ""])
    assert item == nil
  end

  test "fetch_component_access_token" do
    {key, item} = Registry.read_from_local(:fetch_component_access_token, ["appid", ""])
    assert item == nil

    data = %WeChat.Token{access_token: "fake_component_access_token", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    Registry.write_to_local(key, {:ok, data})

    assert Registry.read_from_local(:fetch_component_access_token, ["appid", ""]) == data
  end

  test "defined client expires_in override" do
    assert CustomExpiresInComponentClient.expires_in() == 5000
    assert CustomExpiresInClient.expires_in() == 6000
  end

  test "global read/write and unique" do
    key = "access_token.G1"
    access_token = "test_access_token"
    data = %WeChat.Token{access_token: access_token, timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}

    task = Task.async(fn ->
      Registry.write_to_local(key, {:ok, data})
    end)
    Task.await(task)

    token = Registry.read_from_local(:fetch_access_token, ["G1", ""])
    assert token.access_token == access_token

    Task.async_stream([1, 2, 3], fn(_i) ->
      Registry.read_from_local(:fetch_access_token, ["G1", ""])
    end)
    |> Enum.map(fn {:ok, token} ->
      assert token.access_token == access_token
    end)

    access_token = "test_access_token2"
    data = %WeChat.Token{access_token: access_token, timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    task = Task.async(fn ->
      Registry.write_to_local(key, {:ok, data})
    end)
    Task.await(task)

    token = Registry.read_from_local(:fetch_access_token, ["G1", ""])
    assert token.access_token == access_token

    access_token = "test_access_token3"
    data = Map.put(data, :access_token, access_token)
    Registry.write_to_local(key, {:ok, data})

    token = Registry.read_from_local(:fetch_access_token, ["G1", ""])
    assert token.access_token == access_token
  end
end
