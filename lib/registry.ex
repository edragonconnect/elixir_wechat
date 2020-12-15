defmodule WeChat.Registry do
  @moduledoc false

  use Decorator.Define, [cache: 0]

  alias WeChat.Utils

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

    unregister(key)

    {key, nil}
  end

  def read_from_local(:refresh_access_token, [appid, authorizer_appid, _access_token, _hub_url]) do
    # always clean registry when refresh
    key = key_access_token([appid, authorizer_appid])

    unregister(key)

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
    case Registry.register(__MODULE__, key, value) do
      {:ok, _pid} ->
        :ok
      {:error, {:already_registered, _pid}} ->
        Registry.update_value(__MODULE__, key, fn(_) ->
          value
        end)
    end
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

  defp unregister(key) do
    Registry.unregister(__MODULE__, key)
  end

  defp lookup(key) do
    {
      key,
      Registry.lookup(__MODULE__, key),
    }
  end

  defp use_cache_if_not_expired({key, []}) do
    {key, nil}
  end
  defp use_cache_if_not_expired({key, [{_pid, value}]}) do
    if expired?(value) do
      {key, nil}
    else
      value
    end
  end

end
