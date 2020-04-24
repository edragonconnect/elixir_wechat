defmodule WeChat.Http do
  @moduledoc false
  use Tesla

  require Logger

  plug(Tesla.Middleware.Logger)

  @spec client(request :: WeChat.Request.t()) :: term()
  def client(request) do
    Tesla.client([
      {WeChat.Http.Middleware.Common, request}
    ])
  end

  @spec component_client(request :: WeChat.Request.t()) :: term()
  def component_client(request) do
    Tesla.client([
      {WeChat.Http.Middleware.Component, request}
    ])
  end
end
