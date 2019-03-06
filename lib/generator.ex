defmodule WeChat.APIGenerator do
  @moduledoc false
  require Logger

  @http_get "get"
  @http_post "post"
  @wechat_api_default_host "https://api.weixin.qq.com"
  @ignored_uri_prefix_for_common ["cgi-bin/component"]
  @common_builder WeChat.Builder
  @component_builder WeChat.Component.Builder

  defmodule Utils do
    @moduledoc false

    def check_uri_supplement(_uri_supplement, _method, nil) do
      :ignore
    end
    def check_uri_supplement(uri_supplement, method, ignored_uri_supplements)
        when is_atom(uri_supplement) and is_atom(method) do
      if Atom.to_string(uri_supplement) in ignored_uri_supplements do
        raise(
          ~s(Invalid usecase, set uri_supplement as :#{uri_supplement} is ignored when invoke function `#{method}` in the client scenario.)
        )
      end
    end

  end

  def splice_url(%{uri_prefix: uri_prefix} = configs) do
    host = Map.get(configs, :host, @wechat_api_default_host)
    "#{host}/#{uri_prefix}"
  end

  def splice_url(uri_supplement, %{uri_prefix: uri_prefix} = configs) do
    host = Map.get(configs, :host, @wechat_api_default_host)
    "#{host}/#{uri_prefix}/#{uri_supplement}"
  end

  def execute(opts, toml_config_path, builder_module) do
    using_wechat_common_behaviour = Keyword.get(opts, :using_wechat_common_behaviour, true)
    opts_scenario = Keyword.get(opts, :scenario)
    for {api_method, configs} <- Toml.decode_file!(toml_config_path, keys: :atoms) do
      uri_prefix = Map.get(configs, :uri_prefix)
      config_supported_scenario = Map.get(configs, :scenario)
      config_use_for_component = Map.get(configs, :use_for_component, true)

      if uri_prefix == nil,
        do:
          raise(
            "Error: `uri_prefix` is required for [#{api_method}] in #{toml_config_path}, please set it properly."
          )

      cond do
        config_supported_scenario == nil ->
          if (using_wechat_common_behaviour == false and config_use_for_component == false) do
            :ignore
          else
            execute_building(builder_module, uri_prefix, api_method, configs, opts, using_wechat_common_behaviour)
          end
        is_bitstring(config_supported_scenario) ->
          if String.downcase(config_supported_scenario) == Atom.to_string(opts_scenario) do
            if (using_wechat_common_behaviour == false and config_use_for_component == false) do
              :ignore
            else
              execute_building(builder_module, uri_prefix, api_method, configs, opts, using_wechat_common_behaviour)
            end
          end
        is_map(config_supported_scenario) ->
          client_ignored_funs =
            config_supported_scenario
            |> Map.get(:client, %{})
            |> Map.get(:ignored, %{})
            |> Map.get(:uri_supplement, [])
          if (opts_scenario == :client and length(client_ignored_funs) > 0) do
            execute_building(builder_module, uri_prefix, api_method, configs, opts, using_wechat_common_behaviour, client_ignored_funs)
          else
            execute_building(builder_module, uri_prefix, api_method, configs, opts, using_wechat_common_behaviour)
          end
        true ->
          raise(
            "Error: config `scenario`: #{inspect config_supported_scenario} is invalid, please set it as `hub`, `client` or don not set it."
          )
      end
    end
  end

  defp execute_building(builder, uri_prefix, api_method, configs, opts, using_wechat_common_behaviour, client_ignored_funs \\ nil)
  defp execute_building(@common_builder, uri_prefix, api_method, configs, opts, _using_wechat_common_behaviour = true, client_ignored_funs)
       when uri_prefix not in @ignored_uri_prefix_for_common do
    do_generate(api_method, configs, opts, @common_builder, client_ignored_funs)
  end
  defp execute_building(@common_builder, uri_prefix, api_method, configs, opts, _using_wechat_common_behaviour = false, client_ignored_funs)
       when uri_prefix not in @ignored_uri_prefix_for_common do
    do_generate(api_method, configs, opts, @common_builder, client_ignored_funs, true)
  end
  defp execute_building(@component_builder, _uri_prefix, api_method, configs, opts, _using_wechat_common_behaviour, client_ignored_funs) do
    do_generate(api_method, configs, opts, @component_builder, client_ignored_funs)
  end
  defp execute_building(invalid_builder, uri_prefix, _apid_method, _configs, _opts, _using_wechat_common_behaviour, _client_ignored_funs) do
    raise "Using not supported builder: #{inspect invalid_builder} with uri_prefix: #{inspect uri_prefix}"
  end

  defp do_generate(method, configs, opts, builder_module, client_ignored_funs, require_authorizer_appid \\ false) do
    http_verbs = Map.get(configs, :http_verbs, [@http_get, @http_post])

    quote location: :keep do

      unquote(
        do_generate_doc(
          method,
          configs,
          require_authorizer_appid
        )
      )

      unquote(
        gen_functions_get(
          method,
          configs,
          http_verbs,
          opts,
          builder_module,
          client_ignored_funs,
          require_authorizer_appid
        )
      )

      unquote(
        gen_functions_post(
          method,
          configs,
          http_verbs,
          opts,
          builder_module,
          client_ignored_funs,
          require_authorizer_appid
        )
      )

      unquote(
        gen_functions_post_form(
          method,
          configs,
          http_verbs,
          opts,
          builder_module,
          client_ignored_funs,
          require_authorizer_appid
        )
      )
    end
  end

  defp do_generate_doc(method, configs, require_authorizer_appid) do
    http_verbs = Map.get(configs, :http_verbs, [@http_get, @http_post])
    default_url = splice_url(configs)
    quote location: :keep do
      if unquote(require_authorizer_appid) do
        if @wechat_appid == nil do
          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s).

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, appid, authorizer_appid)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, appid, authorizer_appid)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.
          """
          def unquote(method)(http_verb, appid, authorizer_appid)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, appid, authorizer_appid, uri_supplement)",
                "    #{method}(:#{http}, appid, authorizer_appid, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, appid, authorizer_appid, uri_supplement)",
                "    #{method}(:#{http}, appid, authorizer_appid, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, appid, authorizer_appid, :"${uri_supplement}")
          """
          def unquote(method)(http_verb, appid, authorizer_appid, required)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, appid, authorizer_appid, uri_supplement, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, appid, authorizer_appid, uri_supplement, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, and need to post data or append query string, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, appid, authorizer_appid, :"${uri_supplement}", query)
              #{unquote(method)}(:http_verb, appid, authorizer_appid, :"${uri_supplement}", data)
          """
          def unquote(method)(http_verb, appid, authorizer_appid, uri_supplement, parameters)

        else
          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s) 

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, authorizer_appid)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, authorizer_appid)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.
          """
          def unquote(method)(http_verb, authorizer_appid)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, authorizer_appid, uri_supplement)",
                "    #{method}(:#{http}, authorizer_appid, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, authorizer_appid, uri_supplement)",
                "    #{method}(:#{http}, authorizer_appid, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, authorizer_appid, :"${uri_supplement}")
          """
          def unquote(method)(http_verb, authorizer_appid, parameters)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, authorizer_appid, uri_supplement, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, authorizer_appid, uri_supplement, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, and need to post data or append query string, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, authorizer_appid, :"${uri_supplement}", query)
              #{unquote(method)}(:http_verb, authorizer_appid, :"${uri_supplement}", data)
          """
          def unquote(method)(http_verb, authorizer_appid, uri_supplement, parameters)
        end

      else

        if @wechat_appid == nil do
          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s).

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, appid)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, appid)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.
          """
          def unquote(method)(http_verb, appid)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, appid, uri_supplement)",
                "    #{method}(:#{http}, appid, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, appid, uri_supplement)",
                "    #{method}(:#{http}, appid, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, appid, :"${uri_supplement}")
          """
          def unquote(method)(http_verb, appid, required)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, appid, uri_supplement, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, appid, uri_supplement, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, and need to post data or append query string, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, appid, :"${uri_supplement}", query)
              #{unquote(method)}(:http_verb, appid, :"${uri_supplement}", data)
          """
          def unquote(method)(http_verb, appid, uri_supplement, parameters)
        else
          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s) 

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http})",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http})",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.
          """
          def unquote(method)(http_verb)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, uri_supplement)",
                "    #{method}(:#{http}, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, uri_supplement)",
                "    #{method}(:#{http}, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, :"${uri_supplement}")
          """
          def unquote(method)(http_verb, parameters)

          @doc """
          Perform #{unquote(method |> to_string |> String.upcase())} API(s)

          #{unquote(Enum.map(http_verbs, fn(http) ->
            cond do
              http == "get" ->
                Enum.join([
                "    #{method}(:#{http}, uri_supplement, query)",
                ], "\n") <> "\n"
              http == "post" ->
                Enum.join([
                "    #{method}(:#{http}, uri_supplement, data)",
                ], "\n")
              true ->
                ""
            end
          end))}

          Send request to URL `#{unquote(default_url)}`.

          Refer [WeChat Official Accounts Platform document](https://mp.weixin.qq.com/wiki){:target="_blank"}, if you need to call a service's url is `#{unquote(default_url)}/${uri_supplement}`, and need to post data or append query string, please use `uri_supplement` parameter to construct the corresponding service's complete url, for example:
              #{unquote(method)}(:http_verb, :"${uri_supplement}", query)
              #{unquote(method)}(:http_verb, :"${uri_supplement}", data)
          """
          def unquote(method)(http_verb, uri_supplement, parameters)
        end
      end
    end
  end

  defp gen_functions_get(
         method,
         configs,
         http_verbs,
         opts,
         builder_module,
         client_ignored_funs,
         _require_authorizer_appid = true
       ) do
    if @http_get in http_verbs do
      quote location: :keep do
        if @wechat_appid != nil do
          unquote(gen_func_require_authorizer_but_norequire_self_appid(
            :get,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        else
          unquote(gen_func_require_authorizer_and_self_appid(
            :get,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        end
      end
    end
  end
  defp gen_functions_get(
         method,
         configs,
         http_verbs,
         opts,
         builder_module,
         client_ignored_funs,
         _require_authorizer_appid = false
       ) do
    if @http_get in http_verbs do
      quote location: :keep do
        if @wechat_appid != nil do
          unquote(gen_func_norequire_authorizer_and_self_appid(
            :get,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        else
          unquote(gen_func_norequire_authorizer_but_require_self_appid(
            :get,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        end
      end
    end
  end

  defp gen_functions_post(
         method,
         configs,
         http_verbs,
         opts,
         builder_module,
         client_ignored_funs,
         _require_authorizer_appid = true
       ) do
    if @http_post in http_verbs do
      quote location: :keep do
        if @wechat_appid != nil do
          unquote(gen_func_require_authorizer_but_norequire_self_appid(
            :post,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        else
          unquote(gen_func_require_authorizer_and_self_appid(
            :post,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        end
      end
    end
  end
  defp gen_functions_post(
         method,
         configs,
         http_verbs,
         opts,
         builder_module,
         client_ignored_funs,
         _require_authorizer_appid = false
       ) do
    if @http_post in http_verbs do
      quote location: :keep do
        if @wechat_appid != nil do
          unquote(gen_func_norequire_authorizer_and_self_appid(
            :post,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        else
          unquote(gen_func_norequire_authorizer_but_require_self_appid(
            :post,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        end
      end
    end
  end

  defp gen_functions_post_form(
         method,
         configs,
         http_verbs,
         opts,
         builder_module,
         client_ignored_funs,
         _require_authorizer_appid = true
       ) do
    if Map.get(configs, :with_form_data, false) and @http_post in http_verbs do
      quote location: :keep do
        if @wechat_appid != nil do
          unquote(gen_func_require_authorizer_but_norequire_self_appid(
            :post_form,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        else
          unquote(gen_func_require_authorizer_and_self_appid(
            :post_form,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        end
      end
    end
  end

  defp gen_functions_post_form(
         method,
         configs,
         http_verbs,
         opts,
         builder_module,
         client_ignored_funs,
         _require_authorizer_appid = false
       ) do
    if Map.get(configs, :with_form_data, false) and @http_post in http_verbs do
      quote location: :keep do
        if @wechat_appid != nil do
          unquote(gen_func_norequire_authorizer_and_self_appid(
            :post_form,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        else
          unquote(gen_func_norequire_authorizer_but_require_self_appid(
            :post_form,
            method,
            configs,
            opts,
            builder_module,
            client_ignored_funs
          ))
        end
      end
    end
  end

  defp gen_func_require_authorizer_and_self_appid(:get, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:get, String.t(), String.t()) :: any
      def unquote(method)(:get, appid, authorizer_appid) when is_bitstring(appid) and is_bitstring(authorizer_appid) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :get,
          authorizer_appid,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:get, String.t(), String.t(), keyword()) :: any
      def unquote(method)(:get, appid, authorizer_appid, query)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_list(query) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :get,
          authorizer_appid,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:get, String.t(), String.t(), atom()) :: any
      def unquote(method)(:get, appid, authorizer_appid, uri_supplement)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :get,
          authorizer_appid,
          uri_supplement,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:get, String.t(), String.t(), atom(), keyword()) :: any
      def unquote(method)(:get, appid, authorizer_appid, uri_supplement, query)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_atom(uri_supplement) and is_list(query) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :get,
          authorizer_appid,
          uri_supplement,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end
    end
  end
  defp gen_func_require_authorizer_and_self_appid(:post, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do

      @spec unquote(method)(:post, String.t(), String.t(), map() | String.t()) :: any
      def unquote(method)(:post, appid, authorizer_appid, body)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_map(body)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_bitstring(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post,
          authorizer_appid,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:post, String.t(), String.t(), atom()) :: any
      def unquote(method)(:post, appid, authorizer_appid, uri_supplement)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post,
          authorizer_appid,
          uri_supplement,
          %{},
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:post, String.t(), String.t(), atom(), map() | String.t()) :: any
      def unquote(method)(:post, appid, authorizer_appid, uri_supplement, body)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_atom(uri_supplement) and is_map(body)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_atom(uri_supplement) and is_bitstring(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post,
          authorizer_appid,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end
    end
  end
  defp gen_func_require_authorizer_and_self_appid(:post_form, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:post_form, String.t(), String.t(), map()) :: any
      def unquote(method)(:post_form, appid, authorizer_appid, body)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_map(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post_form,
          authorizer_appid,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:post_form, String.t(), String.t(), atom(), map()) :: any
      def unquote(method)(:post_form, appid, authorizer_appid, uri_supplement, body)
          when is_bitstring(appid) and is_bitstring(authorizer_appid) and is_atom(uri_supplement) and is_map(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post_form,
          authorizer_appid,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end
    end
  end

  defp gen_func_norequire_authorizer_and_self_appid(:get, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:get) :: any
      def unquote(method)(:get) do
        args = [:get, unquote(Macro.escape(configs)), @wechat_app_module, unquote(opts)]
        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:get, keyword()) :: any
      def unquote(method)(:get, query) when is_list(query) do
        args = [
          :get,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:get, atom()) :: any
      def unquote(method)(:get, uri_supplement) when is_atom(uri_supplement) do
        args = [
          :get,
          uri_supplement,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:get, atom(), keyword()) :: any
      def unquote(method)(:get, uri_supplement, query)
          when is_atom(uri_supplement) and is_list(query) do
        args = [
          :get,
          uri_supplement,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end
    end
  end
  defp gen_func_norequire_authorizer_and_self_appid(:post, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do

      @spec unquote(method)(:post, map()) :: any
      def unquote(method)(:post, body)
          when is_map(body)
          when is_bitstring(body) do
        args = [
          :post,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:post, atom()) :: any
      def unquote(method)(:post, uri_supplement)
          when is_atom(uri_supplement) do
        args = [
          :post,
          uri_supplement,
          %{},
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:post, atom(), map() | String.t()) :: any
      def unquote(method)(:post, uri_supplement, body)
          when is_atom(uri_supplement) and is_map(body)
          when is_atom(uri_supplement) and is_bitstring(body) do
        args = [
          :post,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end
    end
  end
  defp gen_func_norequire_authorizer_and_self_appid(:post_form, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:post_form, map()) :: any
      def unquote(method)(:post_form, body) when is_map(body) do
        args = [
          :post_form,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:post_form, :uri_supplement, map()) :: any
      def unquote(method)(:post_form, uri_supplement, body)
          when is_atom(uri_supplement) and is_map(body) do
        args = [
          :post_form,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end
    end
  end

  defp gen_func_require_authorizer_but_norequire_self_appid(:get, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:get, String.t()) :: any
      def unquote(method)(:get, authorizer_appid) when is_bitstring(authorizer_appid) do
        args = [
          :get,
          authorizer_appid,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:get, String.t(), keyword()) :: any
      def unquote(method)(:get, authorizer_appid, query)
          when is_bitstring(authorizer_appid) and is_list(query) do
        args = [
          :get,
          authorizer_appid,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:get, String.t(), atom()) :: any
      def unquote(method)(:get, authorizer_appid, uri_supplement)
          when is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
        args = [
          :get,
          authorizer_appid,
          uri_supplement,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:get, String.t(), atom(), keyword()) :: any
      def unquote(method)(:get, authorizer_appid, uri_supplement, query)
          when is_bitstring(authorizer_appid) and is_atom(uri_supplement) and is_list(query) do
        args = [
          :get,
          authorizer_appid,
          uri_supplement,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end
    end
  end
  defp gen_func_require_authorizer_but_norequire_self_appid(:post, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do

      @spec unquote(method)(:post, String.t(), map() | String.t()) :: any
      def unquote(method)(:post, authorizer_appid, body)
          when is_bitstring(authorizer_appid) and is_map(body)
          when is_bitstring(authorizer_appid) and is_bitstring(body) do
        args = [
          :post,
          authorizer_appid,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:post, String.t(), atom()) :: any
      def unquote(method)(:post, authorizer_appid, uri_supplement)
          when is_bitstring(authorizer_appid) and is_atom(uri_supplement) do
        args = [
          :post,
          authorizer_appid,
          uri_supplement,
          %{},
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:post, String.t(), atom(), map() | String.t()) :: any
      def unquote(method)(:post, authorizer_appid, uri_supplement, body)
          when is_bitstring(authorizer_appid) and is_atom(uri_supplement) and is_map(body)
          when is_bitstring(authorizer_appid) and is_atom(uri_supplement) and
                 is_bitstring(body) do
        args = [
          :post,
          authorizer_appid,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end
    end
  end
  defp gen_func_require_authorizer_but_norequire_self_appid(:post_form, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:post_form, String.t(), map()) :: any
      def unquote(method)(:post_form, authorizer_appid, body)
          when is_bitstring(authorizer_appid) and is_map(body) do
        args = [
          :post_form,
          authorizer_appid,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]

        apply(unquote(builder_module), :do_request_by_component, args)
      end

      @spec unquote(method)(:post_form, String.t(), atom(), map()) :: any
      def unquote(method)(:post_form, authorizer_appid, uri_supplement, body)
          when is_bitstring(authorizer_appid) and is_atom(uri_supplement) and is_map(body) do
        args = [
          :post_form,
          authorizer_appid,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          unquote(opts)
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request_by_component, args)
      end
    end
  end

  defp gen_func_norequire_authorizer_but_require_self_appid(:get, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:get, String.t()) :: any
      def unquote(method)(:get, appid) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [:get, unquote(Macro.escape(configs)), @wechat_app_module, updated_opts]
        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:get, String.t(), keyword()) :: any
      def unquote(method)(:get, appid, query) when is_list(query) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :get,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:get, String.t(), atom()) :: any
      def unquote(method)(:get, appid, uri_supplement) when is_atom(uri_supplement) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :get,
          uri_supplement,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:get, String.t(), atom(), keyword()) :: any
      def unquote(method)(:get, appid, uri_supplement, query)
          when is_atom(uri_supplement) and is_list(query) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :get,
          uri_supplement,
          query,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end
    end
 
  end
  defp gen_func_norequire_authorizer_but_require_self_appid(:post, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:post, String.t(), map() | String.t()) :: any
      def unquote(method)(:post, appid, body)
          when is_bitstring(appid) and is_map(body)
          when is_bitstring(appid) and is_bitstring(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:post, String.t(), atom()) :: any
      def unquote(method)(:post, appid, uri_supplement)
          when is_bitstring(appid) and is_atom(uri_supplement) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post,
          uri_supplement,
          %{},
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:post, String.t(), atom(), map() | String.t()) :: any
      def unquote(method)(:post, appid, uri_supplement, body)
          when is_bitstring(appid) and is_atom(uri_supplement) and is_map(body)
          when is_bitstring(appid) and is_atom(uri_supplement) and is_bitstring(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end
    end
  end
  defp gen_func_norequire_authorizer_but_require_self_appid(:post_form, method, configs, opts, builder_module, client_ignored_funs) do
    quote location: :keep do
      @spec unquote(method)(:post_form, String.t(), map()) :: any
      def unquote(method)(:post_form, appid, body) when is_bitstring(appid) and is_map(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post_form,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]

        apply(unquote(builder_module), :do_request, args)
      end

      @spec unquote(method)(:post_form, String.t(), atom(), map()) :: any
      def unquote(method)(:post_form, appid, uri_supplement, body)
          when is_bitstring(appid) and is_atom(uri_supplement) and is_map(body) do
        updated_opts = unquote(opts) ++ [appid: appid]
        args = [
          :post_form,
          uri_supplement,
          body,
          unquote(Macro.escape(configs)),
          @wechat_app_module,
          updated_opts
        ]
        Utils.check_uri_supplement(uri_supplement, unquote(method), unquote(client_ignored_funs))

        apply(unquote(builder_module), :do_request, args)
      end
    end
  end

end
