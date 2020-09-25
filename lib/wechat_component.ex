defmodule WeChat.Component do
  @moduledoc """
  Use for WeChat official accounts third-party platform applitions, `WeChat` module
  is usually used for WeChat's functional APIs invoke directly, `WeChat.Component` is used to
  call to refetch/refresh authorizer's access token internally.
  """

  require Logger

  alias WeChat.{Utils, Error}

  defmacro __using__(opts \\ []) do
    default_opts =
      opts
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> Keyword.take([:adapter_storage, :appid, :authorizer_appid, :scenario])

    quote do
      def default_opts, do: unquote(default_opts)

      @doc """
      See WeChat.request/2 for more information.
      """
      def request(method, options) do
        options = Utils.merge_keyword(options, unquote(default_opts))
        WeChat.component_request(method, options)
      end

      defoverridable request: 2
    end
  end

  @doc """
  Fetch component access token, when apply it to hub, there will use `verify ticket` to refetch another component access token.
  """
  def fetch_component_access_token(appid, adapter_storage) when is_atom(adapter_storage) do
    fetch_component_access_token(appid, {adapter_storage, nil})
  end

  def fetch_component_access_token(appid, {adapter_storage, args}) do
    case adapter_storage.fetch_component_access_token(appid, args) do
      {:ok, %WeChat.Token{access_token: access_token}} = token when access_token != nil ->
        token

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
            body: %{"component_verify_ticket" => verify_ticket},
            appid: appid,
            adapter_storage: {adapter_storage, args}
          )

        case result do
          {:ok, response} ->
            access_token = Map.get(response.body, "component_access_token")

            {
              :ok,
              %WeChat.Token{access_token: access_token}
            }

          {:error, error} ->
            Logger.error(
              "remote call /cgi-bin/component/api_component_token for appid: #{inspect(appid)} occurs an error: #{
                inspect(error)
              }"
            )

            {:error, error}
        end

      {:error, error} ->
        Logger.error(
          "occur an error: #{inspect(error)} when get component access token for appid: #{
            inspect(appid)
          }"
        )

        raise %WeChat.Error{
          message:
            "verify_ticket is not existed for appid: #{inspect(appid)}, please try re-authorize",
          reason: :verify_ticket_not_found
        }
    end
  end

  @doc """
  Fetch access token, when apply it to hub, there will use `refresh_token` to refresh another access token.
  """
  def fetch_access_token(appid, authorizer_appid, adapter_storage)
      when is_atom(adapter_storage) and adapter_storage != nil do
    fetch_access_token(appid, authorizer_appid, {adapter_storage, nil})
  end

  def fetch_access_token(appid, authorizer_appid, {adapter_storage, args}) do
    token = adapter_storage.fetch_access_token(appid, authorizer_appid, args)

    case token do
      {:ok, %WeChat.Token{access_token: access_token}} when access_token != nil ->
        token

      {:ok, %WeChat.Token{access_token: nil, refresh_token: refresh_token}}
      when refresh_token != nil ->
        refresh_or_refetch_token_to_refresh(
          appid,
          authorizer_appid,
          refresh_token,
          adapter_storage,
          args
        )

      _ ->
        find_and_refresh_access_token(appid, authorizer_appid, adapter_storage, args)
    end
  end

  defp refresh_or_refetch_token_to_refresh(
         appid,
         authorizer_appid,
         authorizer_refresh_token_str,
         adapter_storage,
         args
       ) do
    refresh_result =
      remote_refresh_authorizer_access_token(
        appid,
        authorizer_appid,
        authorizer_refresh_token_str,
        adapter_storage,
        args
      )

    Logger.info(
      ">>>> remote refresh authorizer_access_token result: #{inspect(refresh_result)} <<<<"
    )

    case refresh_result do
      nil ->
        find_and_refresh_access_token(appid, authorizer_appid, adapter_storage, args)

      {:ok, %WeChat.Token{access_token: _access_token}} ->
        refresh_result
    end
  end

  defp remote_refresh_authorizer_access_token(
         appid,
         authorizer_appid,
         authorizer_refresh_token_str,
         adapter_storage,
         args
       ) do
    data = %{
      "authorizer_appid" => authorizer_appid,
      "authorizer_refresh_token" => authorizer_refresh_token_str
    }

    request_result =
      WeChat.request(:post,
        url: "/cgi-bin/component/api_authorizer_token",
        body: data,
        appid: appid,
        authorizer_appid: authorizer_appid,
        adapter_storage: {adapter_storage, args}
      )

    Logger.info(
      ">>>> remote_refresh_authorizer_access_token request_result: #{inspect(request_result)} <<<<"
    )

    case request_result do
      {:ok, response} ->
        {
          :ok,
          %WeChat.Token{
            access_token: Map.get(response.body, "authorizer_access_token")
          }
        }

      {:error, error} ->
        # errcode: 61023, invalid refresh_token
        # try to refetch refresh_token, and then use it to refresh authorizer access_token
        Logger.info(
          "remote_refresh_authorizer_access_token occurs error: #{inspect(error)}, will try to refetch refresh_token and use it to refresh authorizer access_token"
        )

        nil
    end
  end

  defp find_and_refresh_access_token(appid, authorizer_appid, adapter_storage, args) do
    # The cached component refresh token is expired, rerun refresh token by authorizer list.
    case remote_find_authorizer_refresh_token(appid, authorizer_appid, adapter_storage, args) do
      {:ok, refresh_token_str} ->
        Logger.info(
          ">>> refresh_token: #{inspect(refresh_token_str)} from remote_find_authorizer_refresh_token"
        )

        remote_refresh_authorizer_access_token(
          appid,
          authorizer_appid,
          refresh_token_str,
          adapter_storage,
          args
        )

      error ->
        error
    end
  end

  defp remote_find_authorizer_refresh_token(
         appid,
         authorizer_appid,
         adapter_storage,
         args,
         offset \\ 0,
         count \\ 500
       ) do
    request_result =
      WeChat.request(:post,
        appid: appid,
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
