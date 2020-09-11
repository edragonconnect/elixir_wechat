defmodule WeChat.Http.Middleware.Component do
  @moduledoc false
  @behaviour Tesla.Middleware

  alias WeChat.Http.Middleware.Common
  alias WeChat.{Error, Request, Utils}

  require Logger

  def call(env, next, request) do
    execute(env, next, request)
  end

  defp execute(env, next, request) do
    case prepare_request(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        env
        |> Tesla.run(next)
        |> decode_response(env, next, request)
    end
  end

  defp prepare_request(env, request) do
    env
    |> populate_component_access_token(request)
    |> Common.encode_request()
  end

  defp populate_component_access_token(
         env,
         %Request{
           uri: %URI{path: "/sns/oauth2/component/access_token"},
           authorizer_appid: authorizer_appid,
           appid: appid
         } = request
       ) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}

      env ->
        query = Keyword.merge([appid: authorizer_appid, component_appid: appid], env.query)

        {
          Map.put(env, :query, query),
          request
        }
    end
  end

  defp populate_component_access_token(
         env,
         %Request{
           uri: %URI{path: "/cgi-bin/component/api_component_token"},
           appid: appid,
           adapter_storage: {adapter_storage, args}
         } = request
       ) do

    case adapter_storage.fetch_secret_key(appid, args) do
      {:ok, secret} ->
        body =
          env.body
          |> populate_required_into_body([:component_verify_ticket])
          |> Map.put(:component_appid, request.appid)
          |> Map.put(:component_appsecret, secret)

        {
          Map.put(env, :body, body),
          request
        }

      {:error, error} ->
        Logger.error("fail to fetch secret_key for appid: #{inspect(appid)} occurs error: #{inspect(error)}")
        raise "invalid config for appid: #{inspect(appid)}"

    end
  end

  defp populate_component_access_token(
         env,
         %Request{uri: %URI{path: "/cgi-bin/component/api_create_preauthcode"}, appid: appid} =
           request
       ) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        body = populate_required_into_body(env.body, [], %{component_appid: appid})
        {
          Map.put(env, :body, body),
          request
        }
    end
  end

  defp populate_component_access_token(
         env,
         %Request{uri: %URI{path: "/cgi-bin/component/api_query_auth"}, appid: appid} = request
       ) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        body = populate_required_into_body(env.body, [:authorization_code], %{component_appid: appid})
        {
          Map.put(env, :body, body),
          request
        }
    end
  end

  defp populate_component_access_token(
         env,
         %Request{uri: %URI{path: "/cgi-bin/component/api_authorizer_token"}, appid: appid} =
           request
       ) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        body =
          populate_required_into_body(env.body, [:authorizer_appid, :authorizer_refresh_token], %{
            component_appid: appid
          })
        {
          Map.put(env, :body, body),
          request
        }
    end
  end

  defp populate_component_access_token(
         env,
         %Request{uri: %URI{path: "/cgi-bin/component/api_get_authorizer_info"}, appid: appid} =
           request
       ) do

    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        body = populate_required_into_body(env.body, [:authorizer_appid], %{component_appid: appid})
        {
          Map.put(env, :body, body),
          request
        }
    end
  end

  defp populate_component_access_token(
         env,
         %Request{uri: %URI{path: "/cgi-bin/component/api_get_authorizer_option"}, appid: appid} =
           request
       ) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        body =
          populate_required_into_body(env.body, [:authorizer_appid, :option_name], %{
            component_appid: appid
          })
        {
          Map.put(env, :body, body),
          request
        }
    end
  end

  defp populate_component_access_token(
         env,
         %Request{uri: %URI{path: "/cgi-bin/component/api_set_authorizer_option"}, appid: appid} =
           request
       ) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        body =
          populate_required_into_body(env.body, [:authorizer_appid, :option_name, :option_value], %{
            component_appid: appid
          })
        {
          Map.put(env, :body, body),
          request
        }
    end
  end

  defp populate_component_access_token(
         env,
         %Request{uri: %URI{path: "/cgi-bin/component/api_get_authorizer_list"}, appid: appid} =
           request
       ) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        body = populate_required_into_body(env.body, [:offset, :count], %{component_appid: appid})
        {
          Map.put(env, :body, body),
          request
        }
    end
  end

  defp populate_component_access_token(env, request) do
    case append_component_access_token(env, request) do
      {:error, error} ->
        {:error, error}
      env ->
        {env, request}
    end
  end

  defp append_component_access_token(env, %Request{access_token: component_access_token})
       when component_access_token != nil do
    Logger.info(fn ->
      "auto append component_access_token using the latest re-freshed component_access_token: #{
        inspect(component_access_token)
      }"
    end)

    Map.update!(
      env,
      :query,
      &Keyword.put(&1 || [], :component_access_token, component_access_token)
    )
  end

  defp append_component_access_token(env, %Request{adapter_storage: {adapter_storage, args}, appid: appid}) do

    result = fetch_component_access_token(appid, adapter_storage, args)

    case result do
      {:error, error} ->
        {:error, error}
      component_access_token when is_bitstring(component_access_token) ->
        Logger.info(fn ->
          "auto append component_access_token with: #{inspect(component_access_token)}"
        end)

        Map.update!(
          env,
          :query,
          &Keyword.put(&1 || [], :component_access_token, component_access_token)
        )
    end
  end

  defp decode_response({:ok, %{body: body} = response}, env, next, request)
       when body != "" and body != nil do
    case rerun_when_token_expire(env, next, request, response) do
      {:no_retry, json_resp_body} ->
        sync_to_storage_cache(json_resp_body, request)

        {
          :ok,
          %{
            status: response.status,
            headers: response.headers,
            body: json_resp_body
          }
        }

      {retry_result, _} ->
        retry_result
    end
  end

  defp decode_response({:ok, %{body: body} = response}, _env, _next, _request)
       when body == "" or body == nil do
    {:error,
     %Error{reason: :unknown, message: "response body is empty", http_status: response.status}}
  end

  defp decode_response({:error, reason}, _env, _next, _request) do
    Logger.error("occurs error when decode response with reason: #{inspect(reason)}")
    {:error, %Error{reason: reason}}
  end

  defp sync_to_storage_cache(
         %{"authorizer_access_token" => access_token, "expires_in" => expires_in} = response,
         %Request{
           uri: %URI{path: "/cgi-bin/component/api_query_auth"},
           adapter_storage: {adapter_storage, args},
           appid: appid,
           authorizer_appid: authorizer_appid
         }
       )
       when access_token != nil and expires_in != nil do
    authorizer_refresh_token = Map.get(response, "authorizer_refresh_token")

    adapter_storage.save_access_token(
      appid,
      authorizer_appid,
      access_token,
      authorizer_refresh_token,
      args
    )
  end

  defp sync_to_storage_cache(
         %{"authorizer_access_token" => access_token, "expires_in" => expires_in} = response,
         %Request{
           uri: %URI{path: "/cgi-bin/component/api_authorizer_token"},
           adapter_storage: {adapter_storage, args},
           appid: appid,
           authorizer_appid: authorizer_appid
         }
       )
       when access_token != nil and expires_in != nil do
    authorizer_refresh_token = Map.get(response, "authorizer_refresh_token")

    adapter_storage.save_access_token(
      appid,
      authorizer_appid,
      access_token,
      authorizer_refresh_token,
      args
    )
  end

  defp sync_to_storage_cache(
         %{"component_access_token" => component_access_token, "expires_in" => expires_in},
         %Request{
           uri: %URI{path: "/cgi-bin/component/api_component_token"},
           adapter_storage: {adapter_storage, args},
           appid: appid
         }
       )
       when component_access_token != nil and expires_in != nil do
    adapter_storage.save_component_access_token(appid, component_access_token, args)
  end

  defp sync_to_storage_cache(_json_resp_body, _request) do
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
       when is_map(prepared) and is_map(body) and is_bitstring(current_field) do
    current_field_atom = String.to_atom(current_field)

    value =
      Map.get_lazy(body, current_field, fn ->
        Map.get(body, current_field_atom)
      end)

    updated = Map.put(prepared, current_field_atom, value)
    populate_required_into_body(body, rest_fields, updated)
  end

  defp populate_required_into_body(body, [current_field | rest_fields], prepared)
       when is_map(prepared) and is_map(body) and is_atom(current_field) do
    value =
      Map.get_lazy(body, current_field, fn ->
        Map.get(body, to_string(current_field))
      end)

    updated = Map.put(prepared, current_field, value)
    populate_required_into_body(body, rest_fields, updated)
  end

  defp populate_required_into_body(body, [current_field | _rest_fields], prepared)
       when is_map(prepared) and is_map(body) do
    raise "invalid field: #{inspect(current_field)} in body"
  end

  defp populate_required_into_body(body, [current_field | _rest_fields], prepared)
       when is_map(prepared) and is_bitstring(body) and is_bitstring(current_field) do
    updated = Map.put(prepared, String.to_atom(current_field), body)
    populate_required_into_body(body, [], updated)
  end

  defp populate_required_into_body(body, [current_field | _rest_fields], prepared)
       when is_map(prepared) and is_bitstring(body) and is_atom(current_field) do
    updated = Map.put(prepared, current_field, body)
    populate_required_into_body(body, [], updated)
  end

  defp populate_required_into_body(body, [current_field | _rest_fields], prepared)
       when is_map(prepared) and is_bitstring(body) do
    raise "invalid field: #{inspect(current_field)} in body"
  end

  defp populate_required_into_body(nil, fields, prepared)
       when is_map(prepared) and is_list(fields) and fields != [] do
    prepared
  end

  defp populate_required_into_body(body, fields, prepared)
       when is_map(prepared) and is_list(fields) and fields != [] do
    raise "invalid body: #{inspect(body)} while process required fields"
  end

  defp rerun_when_token_expire(env, next, request, %{body: body} = response) do
    json_resp_body = Utils.json_decode(body)
    result = rerun_when_token_expire(env, next, request, json_resp_body, response.query)
    {result, json_resp_body}
  end

  defp rerun_when_token_expire(
         env,
         next,
         %Request{appid: appid, adapter_storage: {adapter_storage, args}} = request,
         %{"errcode" => errcode},
         request_query
       )
       when errcode == 40001
       when errcode == 42001 do
    Logger.info(
      "when invoke wechat component apis occurs expired component_access_token for wechat appid: #{
        appid
      }, will refresh to fetch a new component_access_token"
    )

    refresh_result =
      adapter_storage.refresh_component_access_token(
        appid,
        request_query[:component_access_token],
        args
      )

    case refresh_result do
      {:ok, %WeChat.Token{access_token: new_component_access_token}} ->
        request = Keyword.put(request, :access_token, new_component_access_token)
        execute(env, next, request)

      {:error, error} ->
        {:error, error}
    end
  end

  defp rerun_when_token_expire(
         _env,
         _next,
         %Request{appid: appid},
         %{"errcode" => errcode} = json_resp_body,
         _request_query
       )
       when errcode == 61005
       when errcode == 61006 do
    Logger.error(
      "component_verify_ticket of appid: #{appid} is expired or invalid (errcode: #{errcode}), please re-auth to update verify_ticket"
    )

    {:error,
     %Error{
       reason: :invalid_component_verify_ticket,
       errcode: errcode,
       message: Map.get(json_resp_body, "errmsg")
     }}
  end

  defp rerun_when_token_expire(
         env,
         _next,
         %Request{appid: appid},
         %{"errcode" => errcode} = json_resp_body,
         _request_query
       )
       when errcode == 61023 do
    Logger.info(
      "refresh_token of appid: #{appid} is invalid, will retry fetch, env: #{inspect(env)}"
    )

    {:error,
     %Error{
       reason: :invalid_component_refresh_token,
       errcode: errcode,
       message: Map.get(json_resp_body, "errmsg")
     }}
  end

  defp rerun_when_token_expire(
         _env,
         _next,
         %Request{appid: appid},
         %{"errcode" => errcode} = json_resp_body,
         _request_query
       )
       when errcode == 61004 do
    Logger.error("clientip is not in whitelist of appid: #{appid}")

    {:error,
     %Error{
       reason: :invalid_clientip,
       errcode: errcode,
       message: Map.get(json_resp_body, "errmsg")
     }}
  end

  defp rerun_when_token_expire(_env, _next, _request, _json_resp_body, _request_query) do
    :no_retry
  end

  defp fetch_component_access_token(appid, adapter_storage, args) do
    case adapter_storage.fetch_component_access_token(appid, args) do
      {:ok, %WeChat.Token{access_token: access_token}} when access_token != nil ->
        access_token
      {:ok, %WeChat.Token{access_token: nil}} ->
        component_access_token = remote_get_component_access_token(appid, adapter_storage, args)
        Logger.info("get component_access_token from remote: #{inspect(component_access_token)}")
        component_access_token
      {:error, error} ->
        {:error, error}
    end
  end

  defp remote_get_component_access_token(appid, adapter_storage, args) do

    case adapter_storage.fetch_component_verify_ticket(appid, args) do
      {:ok, verify_ticket} when verify_ticket != nil ->

        Logger.info(
          ">>> verify_ticket when remote_get_component_access_token: #{inspect(verify_ticket)}"
        )

        result =
          WeChat.request(:post,
            url: "/cgi-bin/component/api_component_token",
            body: %{"verify_ticket" => verify_ticket},
            appid: appid,
            adapter_storage: {adapter_storage, args}
          )

        case result do
          {:ok, response} ->
            Map.get(response.body, "component_access_token")

          {:error, error} ->
            Logger.error("remote call /cgi-bin/component/api_component_token for appid: #{inspect(appid)} occurs an error: #{inspect(error)}")
            {:error, error}
        end

      {:error, error} ->
        Logger.error("occur an error: #{inspect(error)} when get component access token for appid: #{inspect(appid)}")
        raise("Error: verify_ticket is nil for appid: #{inspect(appid)}, please try re-authorize")
    end

  end

end
