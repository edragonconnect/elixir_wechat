defmodule WeChat.Builder do
  @moduledoc false
  require Logger

  alias WeChat.{Http, APIGenerator}

  def do_request(:get, %{uri_prefix: "cgi-bin/token"} = configs, module, opts) do
    Logger.info("get access_token, configs: #{inspect(configs)}, module: #{inspect(module)}")
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module)
    |> Http.get_request(url)
  end

  def do_request(:get, configs, module, opts) do
    Logger.info("get request, configs: #{inspect(configs)}")
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module)
    |> Http.get_request(url)
  end

  def do_request(:get, uri_supplement, configs, module, opts) when is_atom(uri_supplement) do
    Logger.info("get request: #{uri_supplement}, configs: #{inspect(configs)}")
    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module)
    |> Http.get_request(url)
  end

  def do_request(:get, query, configs, module, opts) do
    Logger.info("get request, configs: #{inspect(configs)}")
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module)
    |> Http.get_request(url, query)
  end

  def do_request(:post, body, configs, module, opts) do
    Logger.info("post request, configs: #{inspect(configs)}, body: #{inspect(body)}")
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module)
    |> Http.get_request(url, body)
  end

  def do_request(:post_form, body, configs, module, opts) do
    Logger.info("post_form request, configs: #{inspect(configs)}, body: #{inspect(body)}")
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module)
    |> Http.post_form_request(url, body)
  end

  def do_request(:get, uri_supplement, query, configs, module, opts)
      when is_atom(uri_supplement) do
    Logger.info("get request: #{uri_supplement}, configs: #{inspect(configs)}")
    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module)
    |> Http.get_request(url, query)
  end

  def do_request(:post, uri_supplement, body, configs, module, opts)
      when is_atom(uri_supplement) do
    Logger.info(
      "post request: #{uri_supplement}, configs: #{inspect(configs)}, body: #{inspect(body)}"
    )

    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module)
    |> Http.post_request(url, body)
  end

  def do_request(:post_form, uri_supplement, body, configs, module, opts)
      when is_atom(uri_supplement) do
    Logger.info(
      "post_form request: #{uri_supplement}, configs: #{inspect(configs)}, body: #{
        inspect(body)
      }"
    )

    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module)
    |> Http.post_form_request(url, body)
  end

  ## prepare WeChat common apis for WeChat.Component using

  def do_request_by_component(:get, authorizer_appid, configs, module, opts)
      when is_bitstring(authorizer_appid) do
    Logger.info(
      "get request configs: #{inspect(configs)}, authorizer_appid: #{inspect(authorizer_appid)}"
    )

    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.get_request(url)
  end

  def do_request_by_component(:get, authorizer_appid, uri_supplement, configs, module, opts)
      when is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
    Logger.info(
      "get request uri: #{uri_supplement}, configs: #{inspect(configs)}, authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.get_request(url)
  end

  def do_request_by_component(:get, authorizer_appid, query, configs, module, opts)
      when is_bitstring(authorizer_appid) do
    Logger.info(
      "get request, configs: #{inspect(configs)}, authorizer_appid: #{inspect(authorizer_appid)}, query: #{
        inspect(query)
      }"
    )

    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.get_request(url, query)
  end

  def do_request_by_component(:post, authorizer_appid, body, configs, module, opts) do
    Logger.info(
      "post request, configs: #{inspect(configs)}, body: #{inspect(body)}, authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.post_request(url, body)
  end

  def do_request_by_component(:post_form, authorizer_appid, body, configs, module, opts) do
    Logger.info(
      "post_form request, configs: #{inspect(configs)}, body: #{inspect(body)}, authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.post_form_request(url, body)
  end

  def do_request_by_component(
        :get,
        authorizer_appid,
        uri_supplement,
        query,
        configs,
        module,
        opts
      )
      when is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
    Logger.info(
      "get request: #{uri_supplement}, configs: #{inspect(configs)}, authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.get_request(url, query)
  end

  def do_request_by_component(
        :post,
        authorizer_appid,
        uri_supplement,
        body,
        configs,
        module,
        opts
      )
      when is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
    Logger.info(
      "post request uri: #{uri_supplement}, configs: #{inspect(configs)}, body: #{inspect(body)}, authorizer_appid: #{
        inspect(authorizer_appid)
      }"
    )

    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.post_request(url, body)
  end

  def do_request_by_component(
        :post_form,
        authorizer_appid,
        uri_supplement,
        body,
        configs,
        module,
        opts
      )
      when is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
    Logger.info(
      "post_form request uri: #{uri_supplement}, configs: #{inspect(configs)}, body: #{
        inspect(body)
      }, authorizer_appid: #{inspect(authorizer_appid)}"
    )

    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new(module, authorizer_appid)
    |> Http.post_form_request(url, body)
  end

end

defmodule WeChat.Component.Builder do
  @moduledoc false
  require Logger

  alias WeChat.{Http, APIGenerator}

  def do_request(:post, body, configs, module, opts) do
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new_component(module)
    |> Http.post_request(url, body)
  end

  def do_request(:get, uri_supplement, configs, module, opts) when is_atom(uri_supplement) do
    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new_component(module)
    |> Http.get_request(url)
  end

  def do_request(:get, query, configs, module, opts) do
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new_component(module)
    |> Http.get_request(url, query)
  end

  def do_request(:post, uri_supplement, body, configs, module, opts)
      when is_atom(uri_supplement) do
    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new_component(module)
    |> Http.post_request(url, body)
  end

  def do_request(:get, uri_supplement, query, configs, module, opts)
      when is_atom(uri_supplement) do
    url = APIGenerator.splice_url(uri_supplement, configs)

    opts
    |> Http.new_component(module)
    |> Http.get_request(url, query)
  end

  def do_request(:get, configs, module, opts) do
    url = APIGenerator.splice_url(configs)

    opts
    |> Http.new_component(module)
    |> Http.get_request(url)
  end

end
