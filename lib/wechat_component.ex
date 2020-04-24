defmodule WeChat.Component do
  @moduledoc false

  require Logger

  defmacro __using__(opts \\ []) do
    opts =
      opts
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> initialize_opts()

    quote do
      @opts unquote(opts)

      def request(method, options) do
        options = WeChat.Utils.merge_keyword(options, @opts)
        WeChat.request(method, options)
      end
    end
  end

  defp initialize_opts(opts) do
    use_case = Keyword.get(opts, :use_case, :client)

    Keyword.merge(opts,
      adapter_storage: map_adapter_storage(use_case, opts[:adapter_storage]),
      use_case: use_case,
      is_3rd_component: true,
      appid: opts[:appid],
      authorizer_appid: opts[:authorizer_appid]
    )
  end

  defp map_adapter_storage(:client, nil) do
    WeChat.Storage.Adapter.DefaultComponentClient
  end

  defp map_adapter_storage(:client, adapter_storage) do
    WeChat.ensure_implements(adapter_storage, WeChat.Storage.ComponentClient)
    adapter_storage
  end

  defp map_adapter_storage(:hub, adapter_storage) do
    WeChat.ensure_implements(adapter_storage, WeChat.Storage.ComponentHub)
    adapter_storage
  end
end

defmodule WeChat.Component.Base.Local do
  @moduledoc false
  require Logger
  alias WeChat.Error

  def access_token(appid, authorizer_appid, adapter_storage) do
    token = adapter_storage.fetch_access_token(appid, authorizer_appid)

    Logger.info(
      "get access_token appid: #{inspect(appid)}, authorizer_appid: #{inspect(authorizer_appid)}, fetch_access_token: #{
        inspect(token)
      }"
    )

    if token == nil do
      find_and_refresh_access_token(appid, authorizer_appid)
    else
      authorizer_access_token = token.access_token
      authorizer_refresh_token = token.refresh_token

      cond do
        authorizer_access_token != nil ->
          authorizer_access_token

        authorizer_access_token == nil and authorizer_refresh_token != nil ->
          refresh_or_refetch_token_to_refresh(appid, authorizer_appid, authorizer_refresh_token)

        true ->
          find_and_refresh_access_token(appid, authorizer_appid)
      end
    end
  end

  # def refresh_access_token(appid, authorizer_appid, access_token, adapter_storage) do
  #  Logger.info("refresh access_token for authorizer_appid: #{authorizer_appid} within component appid: #{appid}")
  #  adapter_storage.refresh_access_token(
  #    appid,
  #    authorizer_appid,
  #    access_token
  #  )
  # end

  # def component_access_token(appid, adapter_storage) do
  #  component_token = adapter_storage.fetch_component_access_token(appid)
  #  Logger.info "get component_access_token from hub: appid: #{inspect appid}, component_access_token: #{inspect component_token}"
  #  component_token.access_token
  # end

  defp refresh_or_refetch_token_to_refresh(appid, authorizer_appid, authorizer_refresh_token) do
    refresh_result =
      remote_refresh_authorizer_access_token(appid, authorizer_appid, authorizer_refresh_token)

    Logger.info(
      ">>>> remote refresh authorizer_access_token result: #{inspect(refresh_result)} <<<<"
    )

    case refresh_result do
      nil ->
        find_and_refresh_access_token(appid, authorizer_appid)

      authorizer_access_token ->
        authorizer_access_token
    end
  end

  defp find_and_refresh_access_token(appid, authorizer_appid) do
    # The cached component refresh token is expired, rerun refresh token by authorizer list.
    refresh_token = remote_find_authorizer_refresh_token(appid, authorizer_appid)

    Logger.info(
      ">>> refresh_token: #{inspect(refresh_token)} from remote_find_authorizer_refresh_token"
    )

    remote_refresh_authorizer_access_token(appid, authorizer_appid, refresh_token)
  end

  defp remote_refresh_authorizer_access_token(appid, authorizer_appid, authorizer_refresh_token) do
    data = %{
      "authorizer_appid" => authorizer_appid,
      "authorizer_refresh_token" => authorizer_refresh_token
    }

    Logger.info("data: #{inspect(data)}")

    request_result =
      WeChat.request(:post,
        url: "/cgi-bin/component/api_authorizer_token",
        body: data,
        appid: appid
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

  defp remote_find_authorizer_refresh_token(appid, authorizer_appid, offset \\ 0, count \\ 500) do
    request_result =
      WeChat.request(:post,
        url: "/cgi-bin/component/api_get_authorizer_list",
        body: %{"offset" => offset, "count" => count}
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
          Map.get(matched, "refresh_token")
        else
          size_in_list = length(list)

          if size_in_list == 0 or size_in_list == total_count do
            Logger.error(
              "not find matched authorizer_appid: #{authorizer_appid} in authorizer_list, please double check."
            )

            raise %Error{reason: :invalid_authorizer_appid}
          else
            if offset + 1 < total_count do
              remote_find_authorizer_refresh_token(
                appid,
                authorizer_appid,
                offset + size_in_list,
                count
              )
            else
              Logger.error(
                "not find matched authorizer_appid: #{authorizer_appid} in authorizer_list, please double check."
              )

              raise %Error{reason: :invalid_authorizer_appid}
            end
          end
        end

      error ->
        Logger.error("remote_find_authorizer_refresh_token error: #{inspect(error)}")
        error
    end
  end
end

defmodule WeChat.Component.Base.Hub do
  @moduledoc false
  require Logger

  # def access_token(appid, authorizer_appid, adapter_storage) do
  #  token = adapter_storage.fetch_access_token(appid, authorizer_appid)
  #  Logger.info "get access_token: appid: #{inspect appid}, authorizer_appid: #{inspect authorizer_appid}, fetch_access_token: #{inspect token}"
  #  token.access_token
  # end

  # def save_access_token(appid, authorizer_appid, authorizer_access_token, authorizer_refresh_token, adapter_storage) do
  #  Logger.info("save authorizer_access_token for component appid: #{appid}")

  #  adapter_storage.save_access_token(
  #    appid,
  #    authorizer_appid,
  #    authorizer_access_token,
  #    authorizer_refresh_token
  #  )
  # end

  # def refresh_access_token(appid, authorizer_appid, access_token, adapter_storage) do
  #  Logger.info("refresh access_token for authorizer_appid: #{authorizer_appid} within component appid: #{appid}")
  #  adapter_storage.refresh_access_token(
  #    appid,
  #    authorizer_appid,
  #    access_token
  #  )
  # end

  def component_access_token(appid, adapter_storage) do
    component_token = adapter_storage.fetch_component_access_token(appid)
    Logger.info("get component_access_token from local: #{inspect(component_token)}")

    if component_token != nil and component_token.access_token != nil do
      component_token.access_token
    else
      component_access_token = remote_get_component_access_token(appid, adapter_storage)
      Logger.info("get component_access_token from remote: #{inspect(component_access_token)}")
      component_access_token
    end
  end

  # def save_component_access_token(appid, component_access_token, adapter_storage) do
  #  Logger.info("save_component_access_token, component_access_token: #{inspect component_access_token}, adapter_storage: #{adapter_storage}")
  #  adapter_storage.save_component_access_token(appid, component_access_token)
  # end

  # def refresh_component_access_token(appid, component_access_token, adapter_storage) do
  #  Logger.info("refresh component_access_token for appid: #{appid}")
  #  adapter_storage.refresh_component_access_token(appid, component_access_token)
  # end

  # def save_verify_ticket(appid, verify_ticket, adapter_storage) do
  #  adapter_storage.save_component_verify_ticket(appid, verify_ticket)
  # end

  # def verify_ticket(appid, adapter_storage) do
  #  adapter_storage.fetch_component_verify_ticket(appid)
  # end

  defp remote_get_component_access_token(appid, adapter_storage) do
    verify_ticket = adapter_storage.fetch_component_verify_ticket(appid)
    if verify_ticket == nil, do: raise("Error: verify_ticket is nil")

    Logger.info(
      ">>> verify_ticket when remote_get_component_access_token: #{inspect(verify_ticket)}"
    )

    request_result =
      WeChat.request(:post,
        url: "/cgi-bin/component/api_component_token",
        body: %{"verify_ticket" => verify_ticket},
        query: [appid: appid]
      )

    case request_result do
      {:ok, response} ->
        Map.get(response.body, "component_access_token")

      error ->
        Logger.error("remote_get_component_access_token error: #{inspect(error)}")
        error
    end
  end
end
