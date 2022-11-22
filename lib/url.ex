defmodule WeChat.Url do
  @moduledoc false

  def to_refresh_access_token, do: "/refresh/access_token"
  def to_fetch_access_token, do: "/client/access_token"
  def to_fetch_component_access_token, do: "/client/component_access_token"
  def to_refresh_component_access_token, do: "/client/refresh_component_access_token"
  def to_fetch_ticket, do: "/client/ticket"
end
