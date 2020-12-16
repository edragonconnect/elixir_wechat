defmodule WeChat.Registry do
  @moduledoc false

  use Decorator.Define, [cache: 0]
  use GenServer

  alias WeChat.Utils

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    ets = :ets.new(__MODULE__, [:public, :named_table, read_concurrency: true])
    {:ok, ets}
  end

  def cache(body, context) do
    quote do
      import WeChat.Registry, only: [read_from_local: 2, write_to_local: 2]

      case read_from_local(unquote(context.name), unquote(context.args)) do
        {key, nil} ->
          value = unquote(body)
          write_to_local(key, value)
          value
        value ->
          # read from local registry
          {:ok, value}
      end
    end
  end

  def read_from_local(:refresh_access_token, [appid, _access_token, _hub_url]) do
    # always clean registry when refresh
    key = key_access_token([appid])
    delete(key)
    {key, nil}
  end

  def read_from_local(:refresh_access_token, [appid, authorizer_appid, _access_token, _hub_url]) do
    # always clean registry when refresh
    key = key_access_token([appid, authorizer_appid])
    delete(key)
    {key, nil}
  end

  def read_from_local(:fetch_access_token, [appid, authorizer_appid, _hub_url]) do
    [appid, authorizer_appid]
    |> key_access_token()
    |> lookup()
    |> use_cache_if_not_expired()
  end

  def read_from_local(:fetch_access_token, [appid, _hub_url]) do
    [appid]
    |> key_access_token()
    |> lookup()
    |> use_cache_if_not_expired()
  end

  def read_from_local(:fetch_component_access_token, [appid, _hub_url]) do
    [appid]
    |> key_component_access_token()
    |> lookup()
    |> use_cache_if_not_expired()
  end

  def read_from_local(:fetch_ticket, [appid, type, _hub_url]) do
    [appid, type]
    |> key_ticket()
    |> lookup()
    |> use_cache_if_not_expired()
  end

  def read_from_local(:fetch_ticket, [appid, authorizer_appid, type, _hub_url]) do
    [appid, authorizer_appid, type]
    |> key_ticket()
    |> lookup()
    |> use_cache_if_not_expired()
  end

  def write_to_local(key, {:ok, value}) do
    :ets.insert(__MODULE__, {key, value})
  end
  def write_to_local(_key, _) do
    # ignore error case
    :ok
  end

  defp key_access_token(items) do
    Enum.join(["access_token" | items], ".")
  end

  defp key_component_access_token(items) do
    Enum.join(["component_access_token" | items], ".")
  end

  defp key_ticket(items) do
    Enum.join(["ticket" | items], ".")
  end

  defp expired?(value) do
    (Utils.now_unix() - value.timestamp) >= value.expires_in
  end

  defp delete(key) do
    :ets.delete(__MODULE__, key)
  end

  defp lookup(key) do
    case :ets.lookup(__MODULE__, key) do
      [] ->
        {key, nil}
      [{^key, value}] ->
        {key, value}
    end
  end

  defp use_cache_if_not_expired({key, nil}) do
    {key, nil}
  end

  defp use_cache_if_not_expired({key, value}) do
    if expired?(value) do
      {key, nil}
    else
      value
    end
  end

end
