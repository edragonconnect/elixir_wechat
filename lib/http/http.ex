defmodule WeChat.Http do
  @moduledoc false
  use Tesla

  require Logger

  alias WeChat.{Application, Error}

  plug(Tesla.Middleware.Logger)

  @spec client(request :: WeChat.Request.t()) :: term()
  def client(request) do
    Tesla.client(
      [
        {Tesla.Middleware.Retry,
         delay: 500, max_retries: 10, should_retry: &match_should_retry?/1},
        {WeChat.Http.Middleware.Common, request}
      ],
      Application.http_adapter()
    )
  end

  @spec component_client(request :: WeChat.Request.t()) :: term()
  def component_client(request) do
    Tesla.client(
      [
        {Tesla.Middleware.Retry,
         delay: 500, max_retries: 10, should_retry: &match_should_retry?/1},
        {WeChat.Http.Middleware.Component, request}
      ],
      Application.http_adapter()
    )
  end

  @spec component_client :: term()
  def component_client do
    Tesla.client(
      [
        {Tesla.Middleware.Retry,
         delay: 500, max_retries: 10, should_retry: &match_should_retry?/1},
        Tesla.Middleware.JSON
      ],
      Application.http_adapter()
    )
  end

  # for Tesla/Finch adapter current implements
  defp match_should_retry?({:error, %Error{reason: "timeout"}}), do: true
  defp match_should_retry?({:error, %Error{reason: "socket closed"}}), do: true

  # it is a just reserved function match, so far should not happen when use Tesla/Finch adapter
  defp match_should_retry?({:error, %Error{reason: "closed"}}), do: true

  defp match_should_retry?(_) do
    false
  end
end
