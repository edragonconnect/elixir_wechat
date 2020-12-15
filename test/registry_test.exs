defmodule WeChat.RegistryTest do
  use ExUnit.Case, async: false

  alias WeChat.{Registry, Utils}

  test ":fetch_access_token" do
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

  test ":fetch_ticket" do
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

  test ":refresh_access_token" do
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

  test ":fetch_component_access_token" do
    {key, item} = Registry.read_from_local(:fetch_component_access_token, ["appid", ""])
    assert item == nil

    data = %WeChat.Token{access_token: "fake_component_access_token", timestamp: Utils.now_unix(), expires_in: WeChat.expires_in()}
    Registry.write_to_local(key, {:ok, data})

    assert Registry.read_from_local(:fetch_component_access_token, ["appid", ""]) == data
  end

end
