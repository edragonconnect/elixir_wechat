defmodule WeChat.Component do
  @moduledoc false
  require Logger
  alias WeChat.Component.Builder
  alias WeChat.APIGenerator

  @external_resource Path.join(Path.dirname(__DIR__), "config/wechat_component_api.toml")

  defmacro __using__(opts \\ []) do
    opts =
      opts
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> supplement_options()

    quote do

      use WeChat, unquote(opts)

      unquote(generate_base())
      unquote(generate_apis(opts))

    end
  end

  defp supplement_options(opts) do
    scenario = Keyword.get(opts, :scenario, :client)

    adapter_storage =
      if scenario == :client do
        Keyword.get(opts, :adapter_storage, WeChat.Storage.ComponentDefault)
      else
        Keyword.get(opts, :adapter_storage)
      end

    verify_adapter_storage(scenario, adapter_storage)

    Keyword.merge(opts, [
      adapter_storage: adapter_storage,
      scenario: scenario,
      using_wechat_common_behaviour: false
    ])
  end


  defp generate_base() do
    quote do
      if @wechat_appid != nil do
        unquote(generate_base_norequire_appid())
      else
        unquote(generate_base_require_appid())
      end
    end
  end

  defp generate_base_require_appid() do
    quote do
      if @scenario == :hub do

        def get_access_token(appid, authorizer_appid) do
          unquote(__MODULE__).Base.get_access_token(appid, authorizer_appid, __MODULE__, @scenario, @adapter_storage)
        end

        def set_access_token(appid, response_body, options) do
          unquote(__MODULE__).Base.set_access_token(appid, response_body, options, @adapter_storage)
        end

        def refresh_access_token(appid, authorizer_appid, options) do
          unquote(__MODULE__).Base.refresh_access_token(appid, authorizer_appid, options, @adapter_storage)
        end

        def get_component_access_token(appid) do
          unquote(__MODULE__).Base.get_component_access_token(appid, __MODULE__, @scenario, @adapter_storage)
        end

        def set_component_access_token(appid, response_body, options) do
          unquote(__MODULE__).Base.set_component_access_token(appid, response_body, options, @adapter_storage)
        end

        def refresh_component_access_token(appid, options) do
          unquote(__MODULE__).Base.refresh_component_access_token(appid, options, @adapter_storage)
        end

        def set_verify_ticket(appid, verify_ticket) do
          unquote(__MODULE__).Base.set_verify_ticket(appid, verify_ticket, @adapter_storage)
        end

        def get_verify_ticket(appid) do
          unquote(__MODULE__).Base.get_verify_ticket(appid, @adapter_storage)
        end

      else

        def get_access_token(appid, authorizer_appid) do
          unquote(__MODULE__).Base.get_access_token(appid, authorizer_appid, __MODULE__, @scenario, @adapter_storage)
        end


        def get_component_access_token(appid) do
          unquote(__MODULE__).Base.get_component_access_token(appid, __MODULE__, @scenario, @adapter_storage)
        end

        def refresh_access_token(appid, authorizer_appid, options) do
          unquote(__MODULE__).Base.refresh_access_token(appid, authorizer_appid, options, @adapter_storage)
        end
      end

    end
  end

  defp generate_base_norequire_appid() do
    quote do
      if @scenario == :hub do

        def get_access_token(authorizer_appid) do
          unquote(__MODULE__).Base.get_access_token(@wechat_appid, authorizer_appid, __MODULE__, @scenario, @adapter_storage)
        end

        def set_access_token(response_body, options) do
          unquote(__MODULE__).Base.set_access_token(@wechat_appid, response_body, options, @adapter_storage)
        end

        def refresh_access_token(authorizer_appid, options) do
          unquote(__MODULE__).Base.refresh_access_token(@wechat_appid, authorizer_appid, options, @adapter_storage)
        end

        def get_component_access_token() do
          unquote(__MODULE__).Base.get_component_access_token(@wechat_appid, __MODULE__, @scenario, @adapter_storage)
        end

        def set_component_access_token(response_body, options) do
          unquote(__MODULE__).Base.set_component_access_token(@wechat_appid, response_body, options, @adapter_storage)
        end

        def refresh_component_access_token(options) do
          unquote(__MODULE__).Base.refresh_component_access_token(@wechat_appid, options, @adapter_storage)
        end

        def set_verify_ticket(verify_ticket) do
          unquote(__MODULE__).Base.set_verify_ticket(@wechat_appid, verify_ticket, @adapter_storage)
        end

        def get_verify_ticket() do
          unquote(__MODULE__).Base.get_verify_ticket(@wechat_appid, @adapter_storage)
        end

      else

        def get_access_token(authorizer_appid) do
          unquote(__MODULE__).Base.get_access_token(@wechat_appid, authorizer_appid, __MODULE__, @scenario, @adapter_storage)
        end


        def get_component_access_token() do
          unquote(__MODULE__).Base.get_component_access_token(@wechat_appid, __MODULE__, @scenario, @adapter_storage)
        end

        def refresh_access_token(authorizer_appid, options) do
          unquote(__MODULE__).Base.refresh_access_token(@wechat_appid, authorizer_appid, options, @adapter_storage)
        end

      end

    end
  end

  defp generate_apis(opts) do
    APIGenerator.execute(opts, List.first(@external_resource), Builder)
  end

  defp verify_adapter_storage(_scenario = :client, nil) do
    raise %WeChat.Error{reason: :adapter_storage_is_nil, message: "Required adapter_storage is nil  when using as client"}
  end
  defp verify_adapter_storage(_scenario = :client, adapter_storage) do
    WeChat.ensure_implements(adapter_storage, WeChat.Adapter.Storage.ComponentClient, "config adapter_storage as client")
  end
  defp verify_adapter_storage(_scenario = :hub, nil) do
    raise %WeChat.Error{reason: :adapter_storage_is_nil, message: "Required adapter_storage is nil when using as hub"}
  end
  defp verify_adapter_storage(_scenario = :hub, adapter_storage) do
    WeChat.ensure_implements(adapter_storage, WeChat.Adapter.Storage.ComponentHub, "config adapter_storage as hub")
  end

end

defmodule WeChat.Component.Base do
  @moduledoc false
  require Logger

  alias WeChat.Error

  def get_access_token(appid, authorizer_appid, module, scenario = :hub, adapter_storage) do
    token = adapter_storage.get_access_token(appid, authorizer_appid)
    Logger.info "scenario as #{scenario}, get_access_token appid: #{inspect appid}, authorizer_appid: #{inspect authorizer_appid}, get_access_token: #{inspect token}"

    if token == nil do
      find_and_refresh_access_token(appid, authorizer_appid, module)
    else
      authorizer_access_token = token.access_token
      authorizer_refresh_token = token.refresh_token
      cond do
        authorizer_access_token != nil ->
          authorizer_access_token
        authorizer_access_token == nil and authorizer_refresh_token != nil ->
          refresh_or_refetch_token_to_refresh(appid, authorizer_appid, authorizer_refresh_token, module)
        true ->
          find_and_refresh_access_token(appid, authorizer_appid, module)
      end
    end
  end
  def get_access_token(appid, authorizer_appid, _module, scenario = :client, adapter_storage) do
    token = adapter_storage.get_access_token(appid, authorizer_appid)
    Logger.info "scenario as #{scenario}, get_access_token: appid: #{inspect appid}, authorizer_appid: #{inspect authorizer_appid}, get_access_token: #{inspect token}"
    token.access_token
  end

  def set_access_token(appid, response_body, _options, adapter_storage) do
    Logger.info("set authorizer_access_token for component appid: #{appid}, response_body: #{inspect response_body}")

    authorizer_access_token = Map.get(response_body, "access_token")
    authorizer_appid = Map.get(response_body, "authorizer_appid")
    authorizer_refresh_token = Map.get(response_body, "authorizer_refresh_token")

    adapter_storage.save_access_token(
      appid,
      authorizer_appid,
      authorizer_access_token,
      authorizer_refresh_token
    )
  end

  def refresh_access_token(appid, authorizer_appid, options, adapter_storage) do
    Logger.info("refresh access_token for authorizer_appid: #{authorizer_appid} within component appid: #{appid}, options: #{inspect options}")
    access_token = Keyword.get(options, :access_token)
    adapter_storage.refresh_access_token(
      appid,
      authorizer_appid,
      access_token
    )
  end

  def get_component_access_token(appid, module, scenario = :hub, adapter_storage) do
    component_token = adapter_storage.get_component_access_token(appid)
    Logger.info("scenario as #{scenario}, get component_access_token from local: #{inspect component_token}")
    if component_token != nil and component_token.access_token != nil do
      component_token.access_token
    else
      component_access_token = remote_get_component_access_token(appid, module, adapter_storage)
      Logger.info("scenario as #{scenario}, get component_access_token from remote: #{inspect component_access_token}")
      component_access_token
    end
  end
  def get_component_access_token(appid, _module, scenario = :client, adapter_storage) do
    component_token = adapter_storage.get_component_access_token(appid)
    Logger.info "scenario as #{scenario}, get_component_access_token: appid: #{inspect appid}, component_access_token: #{inspect component_token}"
    component_token.access_token
  end

  def set_component_access_token(appid, response_body, options, adapter_storage) do
    Logger.info("** set_component_access_token, response_body: #{inspect response_body}, options: #{inspect options}")
    component_access_token = Map.get(response_body, "component_access_token")
    adapter_storage.save_component_access_token(appid, component_access_token)
  end

  def refresh_component_access_token(appid, options, adapter_storage) do
    Logger.info("refresh component_access_token for appid: #{appid}, options: #{inspect options}, adapter_storage: #{inspect adapter_storage}")
    component_access_token = Keyword.get(options, :component_access_token)
    adapter_storage.refresh_component_access_token(appid, component_access_token)
  end

  def set_verify_ticket(appid, verify_ticket, adapter_storage) do
    adapter_storage.save_component_verify_ticket(appid, verify_ticket)
  end

  def get_verify_ticket(appid, adapter_storage) do
    adapter_storage.get_component_verify_ticket(appid)
  end

  defp refresh_or_refetch_token_to_refresh(appid, authorizer_appid, authorizer_refresh_token, module) do
    refresh_result = remote_refresh_authorizer_access_token(appid, authorizer_appid, authorizer_refresh_token, module)
    Logger.info ">>>> remote refresh authorizer_access_token result: #{inspect refresh_result} <<<<"
    case refresh_result do
      nil ->
        find_and_refresh_access_token(appid, authorizer_appid, module)
      authorizer_access_token ->
        authorizer_access_token
    end
  end

  defp find_and_refresh_access_token(appid, authorizer_appid, module) do
    # The cached component refresh token is expired, rerun refresh token by authorizer list.
    refresh_token = remote_find_authorizer_refresh_token(appid, authorizer_appid, module)
    Logger.info ">>> refresh_token: #{inspect refresh_token} from remote_find_authorizer_refresh_token"
    remote_refresh_authorizer_access_token(appid, authorizer_appid, refresh_token, module)
  end

  defp remote_get_component_access_token(appid, module, adapter_storage) do
    verify_ticket = get_verify_ticket(appid, adapter_storage)
    if verify_ticket == nil, do: raise "Error: verify_ticket is nil"
    Logger.info ">>> verify_ticket when remote_get_component_access_token: #{inspect verify_ticket}"
    request_result =
      cond do
        function_exported?(module, :component, 4) ->
          apply(module, :component, [:post, appid, :api_component_token, verify_ticket])
        true ->
          apply(module, :component, [:post, :api_component_token, verify_ticket])
      end

    case request_result do
      {:ok, response} ->
        Map.get(response.body, "component_access_token")
      {:error, error} ->
        Logger.error("remote_get_component_access_token error: #{inspect error}")
        raise error
    end
  end

  defp remote_refresh_authorizer_access_token(appid, authorizer_appid, authorizer_refresh_token, module) do
    data = %{
      authorizer_appid: authorizer_appid,
      authorizer_refresh_token: authorizer_refresh_token
    }
    Logger.info "data: #{inspect data}"
    request_result =
      cond do
        function_exported?(module, :component, 4) ->
          apply(module, :component, [:post, appid, :api_authorizer_token, data])
        true ->
          apply(module, :component, [:post, :api_authorizer_token, data])
      end
    Logger.info ">>>> remote_refresh_authorizer_access_token request_result: #{inspect request_result} <<<<"
    case request_result do
      {:ok, response} ->
        Map.get(response.body, "authorizer_access_token")
      {:error, error} ->
        # errcode: 61023, invalid refresh_token
        # try to refetch refresh_token, and then use it to refresh authorizer access_token
        Logger.info("remote_refresh_authorizer_access_token occurs error: #{inspect error}, will try to refetch refresh_token and use it to refresh authorizer access_token")
        nil
    end
  end

  defp remote_find_authorizer_refresh_token(appid, authorizer_appid, module, offset \\ 0, count \\ 500) do
    request_result =
      cond do
        function_exported?(module, :component, 4) ->
          apply(module, :component, [:post, appid, :api_get_authorizer_list, %{offset: offset, count: count}])
        true ->
          apply(module, :component, [:post, :api_get_authorizer_list, %{offset: offset, count: count}])
      end

    case request_result do
      {:ok, response} ->
        total_count = Map.get(response.body, "total_count")
        Logger.info("remote get authorizer_list total_count: #{total_count}, offset: #{offset}")
        list = Map.get(response.body, "list")
        matched = 
          Enum.find(list, fn(item) ->
            Map.get(item, "authorizer_appid") == authorizer_appid
          end)
        if matched != nil do
          Map.get(matched, "refresh_token")
        else
          size_in_list = length(list)
          if size_in_list == 0 or size_in_list == total_count do
            Logger.error("not find matched authorizer_appid: #{authorizer_appid} in authorizer_list, please double check.")
            raise %Error{reason: :invalid_authorizer_appid}
          else
            if offset + 1 < total_count do
              remote_find_authorizer_refresh_token(appid, authorizer_appid, module, offset + size_in_list, count)
            else
              Logger.error("not find matched authorizer_appid: #{authorizer_appid} in authorizer_list, please double check.")
              raise %Error{reason: :invalid_authorizer_appid}
            end
          end
        end
      {:error, %Error{reason: :invalid_component_verify_ticket} = error} ->
        raise error
      {:error, error} ->
        Logger.error("remote_find_authorizer_refresh_token error: #{inspect error}")
        raise error
    end
  end

end
