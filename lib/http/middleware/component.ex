defmodule WeChat.Http.Middleware.Component do
  @moduledoc false
  @behaviour Tesla.Middleware

  alias WeChat.Http.Middleware.Common
  alias WeChat.{Http, Error}

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
        {:error, error}
    end
  end

  defp populate_request(env, options) do
    env
    |> populate_component_access_token(options)
    |> Common.encode_request(env.opts)
  end

  defp populate_component_access_token(env, options) do
    populate_component_access_token(URI.parse(env.url), env, options)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_component_token"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)

    updated_body =
      env.body
      |> populate_required_into_body([:component_verify_ticket])
      |> Map.put(:component_appid, credential.appid)
      |> Map.put(:component_appsecret, credential.secret)

    Map.put(env, :body, updated_body)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_create_preauthcode"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)
    updated_env = append_component_access_token(env, options)

    updated_body =
      populate_required_into_body(env.body, [], %{component_appid: credential.appid})

    Map.put(updated_env, :body, updated_body)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_query_auth"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)
    updated_env = append_component_access_token(env, options)

    updated_body =
      populate_required_into_body(env.body, [:authorization_code], %{
        component_appid: credential.appid
      })

    Map.put(updated_env, :body, updated_body)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_authorizer_token"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)
    updated_env = append_component_access_token(env, options)

    updated_body =
      populate_required_into_body(env.body, [:authorizer_appid, :authorizer_refresh_token], %{
        component_appid: credential.appid
      })

    Map.put(updated_env, :body, updated_body)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_get_authorizer_info"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)
    updated_env = append_component_access_token(env, options)

    updated_body =
      populate_required_into_body(env.body, [:authorizer_appid], %{
        component_appid: credential.appid
      })

    Map.put(updated_env, :body, updated_body)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_get_authorizer_option"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)
    updated_env = append_component_access_token(env, options)

    updated_body =
      populate_required_into_body(env.body, [:authorizer_appid, :option_name], %{
        component_appid: credential.appid
      })

    Map.put(updated_env, :body, updated_body)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_set_authorizer_option"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)
    updated_env = append_component_access_token(env, options)

    updated_body =
      populate_required_into_body(env.body, [:authorizer_appid, :option_name, :option_value], %{
        component_appid: credential.appid
      })

    Map.put(updated_env, :body, updated_body)
  end

  defp populate_component_access_token(
         %URI{path: "/cgi-bin/component/api_get_authorizer_list"} = _uri,
         env,
         options
       ) do
    credential = Http.grep_credential(options)
    updated_env = append_component_access_token(env, options)

    updated_body =
      populate_required_into_body(env.body, [:offset, :count], %{
        component_appid: credential.appid
      })

    Map.put(updated_env, :body, updated_body)
  end

  defp populate_component_access_token(_uri, env, options) do
    append_component_access_token(env, options)
  end

  defp append_component_access_token(env, options) do
    wechat_component_module = Keyword.get(options, :module)
    component_access_token =
      cond do
        function_exported?(wechat_component_module, :get_component_access_token, 1) ->
          apply(wechat_component_module, :get_component_access_token, [Http.grep_appid(options)])
        true ->
          apply(wechat_component_module, :get_component_access_token, [])
      end
    Logger.info ">>> append_component_access_token wechat_component_module: #{inspect wechat_component_module}"
    Logger.info ">>> append_component_access_token component_access_token: #{inspect component_access_token}"
    required = [component_access_token: component_access_token]
    Map.update!(env, :query, &(Keyword.merge(&1, required)))
  end

  defp decode_response({:ok, response}, init_env, next, options) do
    Logger.info(">>> decode_response for component")
    Logger.info("#{inspect response}")
    Logger.info("#{inspect init_env}")

    initial = %{
      status: response.status,
      headers: response.headers,
      body: ""
    }

    if response.body != "" do
      response_body = Jason.decode!(response.body)
      request_query = init_env.query
      Logger.info ">>> response_body: #{inspect response_body}"
      Logger.info ">>> request_query: #{inspect request_query}"
      case rerun_when_token_expire(init_env, next, options, response_body, request_query) do
        :ok ->
          request_body = init_env.body
          prepared_request_body =
            if is_bitstring(request_body) do
              Jason.decode!(request_body)
            else
              request_body
            end
          Logger.info ">>> prepared_request_body: #{inspect prepared_request_body}"
          reserve_access_token(URI.parse(response.url), response_body, options, prepared_request_body)
          {:ok, %{initial | body: response_body}}
        retry_result ->
          retry_result
      end
    else
      {:error, %Error{reason: :unknown, message: "response body is empty, http status code: #{inspect(response.status)}"}}
    end
  end

  defp decode_response({:error, reason}, _init_env, _next, _options) do
    Logger.error "occurs error when decode response with reason: #{inspect(reason)}"
    {:error, %Error{reason: reason}}
  end

  defp reserve_access_token(
         %URI{path: "/cgi-bin/component/api_query_auth"},
         response_body,
         options,
         _request_body
       ) do
    access_token = Map.get(response_body, "authorizer_access_token")
    expires_in = Map.get(response_body, "expires_in")

    if access_token != nil and expires_in != nil do
      wechat_module = Keyword.get(options, :module)

      updated_response_body = %{
        "access_token" => access_token,
        "authorizer_appid" => Map.get(response_body, "authorizer_appid"),
        "authorizer_refresh_token" => Map.get(response_body, "authorizer_refresh_token"),
        "expires_in" => expires_in
      }

      apply(wechat_module, :set_access_token, [updated_response_body, options])
    end
  end

  defp reserve_access_token(
         %URI{path: "/cgi-bin/component/api_authorizer_token"},
         response_body,
         options,
         request_body
       ) do
    Logger.info ">>>> reserve_access_token <<<<"
    Logger.info "response_body: #{inspect response_body}, request_body: #{inspect request_body}"
    access_token = Map.get(response_body, "authorizer_access_token")
    expires_in = Map.get(response_body, "expires_in")

    if access_token != nil and expires_in != nil do
      wechat_module = Keyword.get(options, :module)

      authorizer_appid = 
        Map.get_lazy(request_body, "authorizer_appid", fn ->
          Map.get(request_body, :authorizer_appid)
        end)
      Logger.info "authorizer_appid: #{inspect authorizer_appid}"
      updated_response_body = %{
        "access_token" => access_token,
        "authorizer_appid" => authorizer_appid,
        "authorizer_refresh_token" => Map.get(response_body, "authorizer_refresh_token"),
        "expires_in" => expires_in
      }

      apply(wechat_module, :set_access_token, [updated_response_body, options])
    end
  end

  defp reserve_access_token(
         %URI{path: "/cgi-bin/component/api_component_token"},
         response_body,
         options,
         _request_body
       ) do
    component_access_token = Map.get(response_body, "component_access_token")
    expires_in = Map.get(response_body, "expires_in")

    if component_access_token != nil and expires_in != nil do
      wechat_module = Keyword.get(options, :module)

      updated_response_body = %{
        "component_access_token" => component_access_token,
        "expires_in" => expires_in
      }

      apply(wechat_module, :set_component_access_token, [updated_response_body, options])
    end
  end

  defp reserve_access_token(_uri, _response_body, _options, _request_body) do
    :ok
  end

  defp populate_required_into_body(body, fields, prepared \\ %{})

  defp populate_required_into_body(body, [], prepared)
       when is_map(prepared) and is_bitstring(body) do
    prepared
  end

  defp populate_required_into_body(body, [], prepared) when is_map(prepared) and is_map(body) do
    Map.merge(body, prepared)
  end

  defp populate_required_into_body(nil, [], prepared) when is_map(prepared) do
    prepared
  end

  defp populate_required_into_body(body, [], prepared) when is_map(prepared) do
    raise "invalid body: #{inspect(body)} while process required fields"
  end

  defp populate_required_into_body(body, [current_field | rest_fields], prepared)
       when is_map(prepared) and is_map(body) do
    cond do
      is_bitstring(current_field) ->
        current_field_atom = String.to_atom(current_field)

        value =
          Map.get_lazy(body, current_field, fn ->
            Map.get(body, current_field_atom)
          end)

        updated = Map.put(prepared, current_field_atom, value)
        populate_required_into_body(body, rest_fields, updated)

      is_atom(current_field) ->
        value =
          Map.get_lazy(body, current_field, fn ->
            Map.get(body, to_string(current_field))
          end)

        updated = Map.put(prepared, current_field, value)
        populate_required_into_body(body, rest_fields, updated)

      true ->
        raise "invalid field: #{inspect(current_field)} in body"
    end
  end

  defp populate_required_into_body(body, [current_field | _rest_fields], prepared)
       when is_map(prepared) and is_bitstring(body) do
    cond do
      is_bitstring(current_field) ->
        updated = Map.put(prepared, String.to_atom(current_field), body)
        populate_required_into_body(body, [], updated)

      is_atom(current_field) ->
        updated = Map.put(prepared, current_field, body)
        populate_required_into_body(body, [], updated)

      true ->
        raise "invalid field: #{inspect(current_field)} in body"
    end
  end

  defp populate_required_into_body(nil, fields, prepared)
       when is_map(prepared) and length(fields) > 0 do
    prepared
  end

  defp populate_required_into_body(body, fields, prepared)
       when is_map(prepared) and length(fields) > 0 do
    raise "invalid body: #{inspect(body)} while process required fields"
  end

  defp rerun_when_token_expire(env, next, options, response_result, request_query) do
    errcode = Map.get(response_result, "errcode")
    cond do
      errcode in [40001, 42001] ->
        wechat_appid = Http.grep_appid(options)
        wechat_module = Keyword.get(options, :module)
        Logger.info "when invoke wechat component apis occurs expired component_access_token for wechat_appid: #{wechat_appid}, will clean and refetch component_access_token"
        apply(wechat_module, :clean_component_access_token, [Keyword.merge(options, request_query)])
        execute(env, next, options)
      errcode in [61005, 61006] ->
        wechat_appid = Http.grep_appid(options)
        Logger.error "component_verify_ticket of appid: #{wechat_appid} is expired or invalid (errcode: #{errcode}), please re-auth or update verify_ticket"
        {:error, %Error{reason: :invalid_component_verify_ticket, errcode: errcode, message: Map.get(response_result, "errmsg")}}
      errcode == 61023 ->
        wechat_appid = Http.grep_appid(options)
        Logger.info "refresh_token of appid: #{wechat_appid} is invalid, will retry fetch, env: #{inspect env}"
        {:error, %Error{reason: :invalid_component_refresh_token, errcode: errcode, message: Map.get(response_result, "errmsg")}}
      errcode == 61004 ->
        wechat_appid = Http.grep_appid(options)
        Logger.error "clientip is not in whitelist of appid: #{wechat_appid}"
        {:error, %Error{reason: :invalid_clientip, errcode: errcode, message: Map.get(response_result, "errmsg")}}
      true ->
        :ok
    end
  end

end
