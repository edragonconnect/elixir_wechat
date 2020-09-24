defmodule WeChat.Http.Middleware.Common do
  @moduledoc false
  @behaviour Tesla.Middleware

  alias Tesla.Multipart
  alias WeChat.{UploadMedia, UploadMediaContent, Error, Request, Utils}

  require Logger

  def call(env, next, request) do
    execute(env, next, request)
  end

  defp execute(env, next, request) do
    case try_use_from_cache(env, request) do
      {:cont, env, request} ->
        case prepare_request(env, request) do
          {:error, error} ->
            {:error, error}

          env ->
            env
            |> Tesla.run(next)
            |> decode_response(env, next, request)
        end

      {:cached, result} ->
        {:ok, result}
    end
  end

  defp try_use_from_cache(
         env,
         %Request{authorizer_appid: nil, uri: %URI{path: "/cgi-bin/ticket/getticket"}, adapter_storage: {adapter_storage, args}} = request
       ) do

    type = Keyword.get(request.query, :type)

    appid = request.appid

    case adapter_storage.fetch_ticket(appid, type, args) do
      {:ok, ticket} ->
        {
          :cached,
          %{
            status: 200,
            body: %{"errcode" => 0, "errmsg" => "ok", "ticket" => ticket},
            headers: []
          }
        }

      {:error, _} ->
        {:cont, env, request}
    end
  end

  defp try_use_from_cache(
         env,
         %Request{authorizer_appid: authorizer_appid, uri: %URI{path: "/cgi-bin/ticket/getticket"}, adapter_storage: {adapter_storage, args}} = request
       ) do

    type = Keyword.get(request.query, :type)

    appid = request.appid

    case adapter_storage.fetch_ticket(appid, authorizer_appid, type, args) do
      {:ok, ticket} ->
        {
          :cached,
          %{
            status: 200,
            body: %{"errcode" => 0, "errmsg" => "ok", "ticket" => ticket},
            headers: []
          }
        }

      {:error, _} ->
        {:cont, env, request}
    end

  end

  defp try_use_from_cache(env, request) do
    {:cont, env, request}
  end

  defp prepare_request(env, request) do
    env
    |> populate_access_token(request)
    |> encode_request()
  end

  defp populate_access_token(
         env,
         %Request{
           uri: %URI{path: "/cgi-bin/token"},
           appid: appid,
           adapter_storage: {adapter_storage, args}
         } = request
       ) do

    case adapter_storage.fetch_secret_key(appid, args) do
      {:ok, secret} ->
        prepared_query = [
          grant_type: "client_credential",
          appid: request.appid,
          secret: secret
        ]

        {Map.update!(env, :query, &Keyword.merge(&1, prepared_query)), request}

      nil ->
        Logger.error("not found secret_key for appid: #{inspect(appid)}")

        prepared_query = [appid: request.appid]

        {Map.update!(env, :query, &Keyword.merge(&1, prepared_query)), request}
    end

  end

  defp populate_access_token(env, %Request{uri: %URI{path: "/sns/userinfo"}} = request) do
    # Use oauth authorized access_token to fetch user information,
    # in this case, we don't need to populate the general access_token.
    {env, request}
  end

  defp populate_access_token(
         env,
         %Request{
           access_token: nil,
           authorizer_appid: nil,
           appid: appid,
           adapter_storage: {adapter_storage, args}
         } = request
       ) do
    case adapter_storage.fetch_access_token(appid, args) do
      {:ok, %WeChat.Token{access_token: access_token}} ->
        {Map.update!(env, :query, &Keyword.put(&1 || [], :access_token, access_token)), request}

      {:error, error} ->
        {:error, error}
    end
  end

  defp populate_access_token(
         env,
         %Request{
           access_token: nil,
           authorizer_appid: authorizer_appid,
           appid: appid,
           adapter_storage: {adapter_storage, args}
         } = request
       )
       when authorizer_appid != nil do
    case WeChat.Component.fetch_access_token(appid, authorizer_appid, {adapter_storage, args}) do
      {:ok, %WeChat.Token{access_token: access_token}} when access_token != nil ->
        {Map.update!(env, :query, &Keyword.put(&1 || [], :access_token, access_token)), request}

      {:error, error} ->
        {:error, error}
    end
  end

  defp populate_access_token(env, %Request{access_token: access_token} = request) do
    # Use the latest re-freshed access_token from `request`
    request = Map.put(request, :access_token, nil)
    {Map.update!(env, :query, &Keyword.put(&1 || [], :access_token, access_token)), request}
  end

  def encode_request({:error, error}) do
    {:error, error}
  end

  def encode_request({env, %Request{body: {:form, body}}}) do
    mp =
      Enum.reduce(body, Multipart.new(), fn {key, value}, acc ->
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

    body_binary = mp |> Multipart.body() |> Enum.join()
    headers = Multipart.headers(mp)

    env
    |> Map.put(:body, body_binary)
    |> Tesla.put_headers(headers)
  end

  def encode_request({env, _request}) do
    with {:ok, env} <- Tesla.Middleware.JSON.encode(env, env.opts || []) do
      env
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

      {retry_result, _json_resp_body} ->
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
         %{"access_token" => access_token},
         %Request{
           uri: %URI{path: "/cgi-bin/token"},
           adapter_storage: {adapter_storage, args},
           appid: appid
         }
       ) do
    adapter_storage.save_access_token(appid, access_token, args)
  end

  defp sync_to_storage_cache(
         %{"ticket" => ticket},
         %Request{
           uri: %URI{path: "/cgi-bin/ticket/getticket"},
           query: query,
           adapter_storage: {adapter_storage, args},
           appid: appid,
           authorizer_appid: authorizer_appid
         }
       )
       when authorizer_appid != nil do
    type = Keyword.get(query, :type)
    adapter_storage.save_ticket(appid, authorizer_appid, ticket, type, args)
  end

  defp sync_to_storage_cache(
         %{"ticket" => ticket},
         %Request{
           uri: %URI{path: "/cgi-bin/ticket/getticket"},
           query: query,
           adapter_storage: {adapter_storage, args},
           appid: appid,
           authorizer_appid: nil
         }
       ) do
    type = Keyword.get(query, :type)
    adapter_storage.save_ticket(appid, ticket, type, args)
  end

  defp sync_to_storage_cache(_json_resp_body, _request) do
    :ok
  end

  defp rerun_when_token_expire(env, next, request, %{body: body} = response) do
    json_resp_body = Utils.json_decode(body)
    result = rerun_when_token_expire(env, next, request, json_resp_body, response.query)
    {result, json_resp_body}
  end

  defp rerun_when_token_expire(
         env,
         next,
         %Request{
           appid: appid,
           authorizer_appid: authorizer_appid,
           adapter_storage: {adapter_storage, args}
         } = request,
         %{"errcode" => errcode},
         request_query
       )
       when errcode == 40001
       when errcode == 42001
       when errcode == 40014 do
    #
    # errcode from WeChat 40001/42001: expired access_token
    # errcode from WeChat 40014: invalid access_token
    #
    expired_access_token = Keyword.get(request_query, :access_token)

    refresh_result =
      if authorizer_appid != nil do
        adapter_storage.refresh_access_token(appid, authorizer_appid, expired_access_token, args)
      else
        adapter_storage.refresh_access_token(appid, expired_access_token, args)
      end

    case refresh_result do
      {:ok, %WeChat.Token{access_token: new_access_token}} ->
        request = Map.put(request, :access_token, new_access_token)
        execute(env, next, request)

      {:error, error} ->
        {:error, error}
    end
  end

  defp rerun_when_token_expire(
         _env,
         _next,
         request,
         %{"errcode" => errcode} = json_resp_body,
         _request_query
       )
       when errcode == 61024 do
    Logger.error(
      "invalid usecase to get access_token of authorizer appid(#{request.authorizer_appid}) by WeChat Component Application(#{
        request.appid
      })"
    )

    {:error,
     %Error{
       reason: :invalid_usecase_get_access_token,
       errcode: errcode,
       message: Map.get(json_resp_body, "errmsg")
     }}
  end

  defp rerun_when_token_expire(_env, _next, _request, _json_resp_body, _request_query) do
    :no_retry
  end

end
