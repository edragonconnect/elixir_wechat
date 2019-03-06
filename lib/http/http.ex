defmodule WeChat.Http do
  @moduledoc false
  use Tesla

  require Logger

  plug(Tesla.Middleware.Logger)

  def new(wechat_opts, module) do
    opts = [wechat: wechat_opts, module: module]
    Tesla.client([
      {WeChat.Http.Middleware.Common, opts},
    ])
  end

  def new(wechat_opts, module, authorizer_appid) do
    opts = [wechat: wechat_opts, module: module, authorizer_appid: authorizer_appid]
    Tesla.client([
      {WeChat.Http.Middleware.Common, opts},
    ])
  end

  def new_component(wechat_opts, module) do
    opts = [wechat: wechat_opts, module: module]
    Tesla.client([
      {WeChat.Http.Middleware.Component, opts},
    ])
  end

  def get_request(client, url) do
    get(client, url)
  end

  def get_request(client, url, query) do
    get(client, url, query: query)
  end

  def post_request(client, url, body) do
    post(client, url, body)
  end

  def post_form_request(client, url, body) do
    post(client, url, body, opts: [with_form_data: true])
  end

  def grep_credential(options) do
    appid = grep_appid(options)
    adapter_storage = get_adapter_storage(options)
    secret = adapter_storage.get_secret_key(appid)
    %{appid: appid, secret: secret}
  end

  def grep_appid(options) do
    options |> Keyword.get(:wechat) |> Keyword.get(:appid)
  end

  def get_adapter_storage(options) do
    options |> Keyword.get(:wechat) |> Keyword.get(:adapter_storage)
  end

end
