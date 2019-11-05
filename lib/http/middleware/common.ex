defmodule WeChat.Http.Middleware.Common do
  @moduledoc false
  @behaviour Tesla.Middleware

  alias Tesla.Multipart
  alias WeChat.{UploadMedia, UploadMediaContent, Http, Error}

  require Logger

  def call(env, next, options) do
    execute(env, next, options)
  end

  defp execute(env, next, options) do
    try do
      updated_env = populate_request(env, options)
      response = Tesla.run(updated_env, next)
      decode_response(response, updated_env, next, options)
    rescue
      error ->
        Logger.error ">>>> occur error in common middleware: #{inspect error} <<<<"
        {:error, error}
    end
  end

  defp populate_request(env, options) do
    env
    |> populate_access_token(options)
    |> encode_request(env.opts)
  end

  defp populate_access_token(env, options) do
    populate_access_token(URI.parse(env.url), env, options)
  end

  defp populate_access_token(%URI{path: "/cgi-bin/token"} = _uri, env, options) do
    credential = Http.grep_credential(options)

    prepared_query = [
      grant_type: "client_credential",
      appid: credential.appid,
      secret: credential.secret
    ]

    Map.update!(env, :query, &(Keyword.merge(&1, prepared_query)))
  end

  defp populate_access_token(%URI{path: "/sns/userinfo"} = _uri, env, _options) do
    # use oauth authorized access_token to fetch user information
    # in this case, we don't need to populate the general access_token.
    env
  end

  defp populate_access_token(_uri, env, options) do
    fresh_access_token = Keyword.get(options, :fresh_access_token)

    required =
      if fresh_access_token == nil do
        wechat_module = Keyword.get(options, :module)

        using_wechat_common_behaviour = Keyword.get(options, :wechat, []) |> Keyword.get(:using_wechat_common_behaviour, true)

        access_token =
          if using_wechat_common_behaviour == true do
            cond do
              function_exported?(wechat_module, :get_access_token, 1) ->
                appid = Http.grep_appid(options)
                apply(wechat_module, :get_access_token, [appid])
              true ->
                apply(wechat_module, :get_access_token, [])
            end
          else
            authorizer_appid = Keyword.get(options, :authorizer_appid)
            cond do
              function_exported?(wechat_module, :get_access_token, 2) ->
                appid = Http.grep_appid(options)
                apply(wechat_module, :get_access_token, [appid, authorizer_appid])
              true ->
                apply(wechat_module, :get_access_token, [authorizer_appid])
            end
          end
        Logger.info(">>> auto populate_access_token #{wechat_module} with access_token: #{access_token}")
        [access_token: access_token]
      else
        Logger.info(">>> auto populate_access_token using the latest refreshed access_token: #{fresh_access_token}")
        [access_token: fresh_access_token]
      end

    Map.update!(env, :query, &(Keyword.merge(&1, required)))
  end

  def encode_request(env, opts) do
    if Keyword.get(opts, :with_form_data, false) do
      mp =
        Enum.reduce(env.body, Multipart.new(), fn {key, value}, acc ->
          case value do
            %UploadMedia{} ->
              acc
              |> Multipart.add_file(value.file_path, name: "#{key}", detect_content_type: true)
              |> Multipart.add_field("type", value.type)

            %UploadMediaContent{} ->
              acc
              |> Multipart.add_file_content(value.file_content, value.file_name, name: "#{key}")
              |> Multipart.add_field("type", value.type)

            _ ->
              Multipart.add_field(acc, "#{key}", "#{value}")
          end
        end)

      body_binary = Enum.join(Multipart.body(mp))
      headers = Multipart.headers(mp)

      env
      |> Map.put(:body, body_binary)
      |> Tesla.put_headers(headers)
    else
      with {:ok, env} <- Tesla.Middleware.JSON.encode(env, opts) do
        env
      end
    end
  end

  def decode_response({:ok, response}, init_env, next, options) do
    initial = %{
      status: response.status,
      headers: response.headers,
      body: ""
    }
    response_body = response.body
    if response_body != "" and response_body != nil do
      response_body = decode_response_body(response_body)
      request_query = response.query
      case rerun_when_token_expire(init_env, next, options, response_body, request_query) do
        :ok ->
          reserve_access_token(URI.parse(response.url), response_body, options)
          {:ok, %{initial | body: response_body}}
        retry_result ->
          retry_result
      end
    else
      {:error, %Error{reason: :unknown, message: "response body is empty, http status code: #{inspect(response.status)}"}}
    end
  end

  def decode_response({:error, reason}, _init_env, _next, _options) do
    Logger.error "occurs error when decode response with reason: #{inspect(reason)}"
    {:error, %Error{reason: reason}}
  end

  defp decode_response_body(body) do
    case Jason.decode(body) do
      {:ok, result} ->
        result
      {:error, _} ->
        body
    end
  end

  defp reserve_access_token(%URI{path: "/cgi-bin/token"}, response_body, options) do
    wechat_module = Keyword.get(options, :module)
    appid = Http.grep_appid(options)
    apply(wechat_module, :set_access_token, [appid, response_body, options])
  end

  defp reserve_access_token(_uri, _response_body, _options) do
    :ok
  end

  defp rerun_when_token_expire(env, next, options, response_result, request_query) when is_map(response_result) do
    # errcode from WeChat 40001/42001: expired access_token
    # errcode from WeChat 40014: invalid access_token
    errcode = Map.get(response_result, "errcode")
    cond do
      errcode in [40001, 42001, 40014] ->
        appid = Http.grep_appid(options)
        wechat_module = Keyword.get(options, :module)

        using_wechat_common_behaviour = Keyword.get(options, :wechat, []) |> Keyword.get(:using_wechat_common_behaviour, true)

        new_access_token =
          if using_wechat_common_behaviour == true do
            Logger.info "refresh_access_token for common application, wechat_module: #{inspect wechat_module}, appid: #{inspect appid}"
            cond do
              function_exported?(wechat_module, :refresh_access_token, 2) ->
                apply(wechat_module, :refresh_access_token, [appid, Keyword.merge(options, request_query)])
              true ->
                apply(wechat_module, :refresh_access_token, [Keyword.merge(options, request_query)])
            end
          else
            authorizer_appid = Keyword.get(options, :authorizer_appid)
            Logger.info "refresh_access_token for component application, wechat_module: #{inspect wechat_module}, appid: #{inspect appid}, authorizer_appid: #{inspect authorizer_appid}"
            cond do
              function_exported?(wechat_module, :refresh_access_token, 3) ->
                apply(wechat_module, :refresh_access_token, [appid, authorizer_appid, Keyword.merge(options, request_query)])
              true ->
                apply(wechat_module, :refresh_access_token, [authorizer_appid, Keyword.merge(options, request_query)])
            end
          end

        updated_options = Keyword.put(options, :fresh_access_token, new_access_token)
        execute(env, next, updated_options)
      errcode == 61024 ->
        Logger.error "invalid usecase to get access_token of authorizer_appid by wechat component"
        {:error, %Error{reason: :invalid_usecase_get_access_token, errcode: errcode, message: Map.get(response_result, "errmsg")}}
      true ->
        :ok
    end
  end
  defp rerun_when_token_expire(_env, _next, _options, _response_result, _request_query) do
    :ok
  end

end
