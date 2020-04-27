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
    case try_use_storage_cache(env, request) do
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
        result
    end
  end

  defp try_use_storage_cache(
         env,
         %Request{uri: %URI{path: "/cgi-bin/ticket/getticket"}, adapter_storage: {adapter_storage, args}} = request
       ) do
    authorizer_appid = request.authorizer_appid

    type = Keyword.get(request.query, :type)

    appid = request.appid

    result =
      if authorizer_appid != nil do
        adapter_storage.fetch_ticket(appid, authorizer_appid, type, args)
      else
        adapter_storage.fetch_ticket(appid, type, args)
      end

    case result do
      {:ok, ticket} ->
        {
          :cached,
          %{
            body: %{"errcode" => 0, "errmsg" => "ok", "ticket" => ticket},
            headers: []
          }
        }

      {:error, _} ->
        {:cont, env, request}
    end
  end

  defp try_use_storage_cache(env, request) do
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
    prepared_query = [
      grant_type: "client_credential",
      appid: request.appid,
      secret: adapter_storage.secret_key(appid, args)
    ]

    {Map.update!(env, :query, &Keyword.merge(&1, prepared_query)), request}
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
    case fetch_access_token_by_component(appid, authorizer_appid, adapter_storage, args) do
      access_token when is_bitstring(access_token) ->
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

  defp fetch_access_token_by_component(appid, authorizer_appid, adapter_storage, args) do
    case adapter_storage.fetch_access_token(appid, authorizer_appid, args) do
      {:ok, %WeChat.Token{access_token: access_token}} when access_token != nil ->
        access_token
      {:ok, %WeChat.Token{access_token: nil, refresh_token: refresh_token}} when refresh_token != nil ->
        refresh_or_refetch_token_to_refresh(appid, authorizer_appid, refresh_token, adapter_storage, args)
      _ ->
        find_and_refresh_access_token(appid, authorizer_appid, adapter_storage, args)
    end
  end

  defp refresh_or_refetch_token_to_refresh(appid, authorizer_appid, authorizer_refresh_token, adapter_storage, args) do
    refresh_result =
      remote_refresh_authorizer_access_token(appid, authorizer_appid, authorizer_refresh_token, adapter_storage, args)

    Logger.info(
      ">>>> remote refresh authorizer_access_token result: #{inspect(refresh_result)} <<<<"
    )

    case refresh_result do
      nil ->
        find_and_refresh_access_token(appid, authorizer_appid, adapter_storage, args)

      authorizer_access_token ->
        authorizer_access_token
    end
  end

  defp find_and_refresh_access_token(appid, authorizer_appid, adapter_storage, args) do
    # The cached component refresh token is expired, rerun refresh token by authorizer list.
    case remote_find_authorizer_refresh_token(appid, authorizer_appid, adapter_storage, args) do
      {:ok, refresh_token} ->
        Logger.info(
          ">>> refresh_token: #{inspect(refresh_token)} from remote_find_authorizer_refresh_token"
        )
        remote_refresh_authorizer_access_token(appid, authorizer_appid, refresh_token, adapter_storage, args)
      error ->
        error
    end
  end

  defp remote_refresh_authorizer_access_token(appid, authorizer_appid, authorizer_refresh_token, adapter_storage, args) do
    data = %{
      "authorizer_appid" => authorizer_appid,
      "authorizer_refresh_token" => authorizer_refresh_token
    }

    Logger.info("data: #{inspect(data)}")

    request_result =
      WeChat.request(:post,
        url: "/cgi-bin/component/api_authorizer_token",
        body: data,
        appid: appid,
        adapter_storage: {adapter_storage, args}
      )

    Logger.info(
      ">>>> remote_refresh_authorizer_access_token request_result: #{inspect(request_result)} <<<<"
    )

    case request_result do
      {:ok, response} ->
        Map.get(response.body, "authorizer_access_token")

      {:error, error} ->
        # errcode: 61023, invalid refresh_token
        # try to refetch refresh_token, and then use it to refresh authorizer access_token
        Logger.info(
          "remote_refresh_authorizer_access_token occurs error: #{inspect(error)}, will try to refetch refresh_token and use it to refresh authorizer access_token"
        )

        nil
    end
  end

  defp remote_find_authorizer_refresh_token(appid, authorizer_appid, adapter_storage, args, offset \\ 0, count \\ 500) do
    request_result =
      WeChat.request(:post,
        url: "/cgi-bin/component/api_get_authorizer_list",
        body: %{"offset" => offset, "count" => count},
        adapter_storage: {adapter_storage, args}
      )

    case request_result do
      {:ok, response} ->
        total_count = Map.get(response.body, "total_count")
        Logger.info("remote get authorizer_list total_count: #{total_count}, offset: #{offset}")
        list = Map.get(response.body, "list")

        matched =
          Enum.find(list, fn item ->
            Map.get(item, "authorizer_appid") == authorizer_appid
          end)

        if matched != nil do
          {:ok, Map.get(matched, "refresh_token")}
        else
          size_in_list = length(list)

          if size_in_list == 0 or size_in_list == total_count do
            Logger.error(
              "not find matched authorizer_appid: #{authorizer_appid} in authorizer_list, please double check."
            )
            {:error, %Error{reason: :invalid_authorizer_appid}}
          else
            if offset + 1 < total_count do
              remote_find_authorizer_refresh_token(
                appid,
                authorizer_appid,
                adapter_storage,
                args,
                offset + size_in_list,
                count
              )
            else
              Logger.error(
                "not find matched authorizer_appid: #{authorizer_appid} in authorizer_list, please double check."
              )
              {:error, %Error{reason: :invalid_authorizer_appid}}
            end
          end
        end

      {:error, error} ->
        Logger.error("remote_find_authorizer_refresh_token error: #{inspect(error)}")
        {:error, error}
    end
  end

end
