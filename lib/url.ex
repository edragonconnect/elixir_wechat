defmodule WeChat.Url do
  def to_refresh_access_token() do
    "/refresh/access_token"
  end

  def to_fetch_access_token() do
    "/client/access_token"
  end

  def to_fetch_component_access_token() do
    "/client/component_access_token"
  end

  def to_fetch_ticket() do
    "/client/ticket"
  end
end
