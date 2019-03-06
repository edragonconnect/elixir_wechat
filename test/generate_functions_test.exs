defmodule WeChatGenerateTest do
  use ExUnit.Case
  doctest WeChat

  defmodule Test1 do
    # test case config appid in global, no need to input appid when invoke wechat functions
    use WeChat, appid: "fakeappid"
  end

  defmodule Test2 do
    # test case require input appid when invoke wechat functions
    use WeChat
  end

  defmodule Test1.Component do
    use WeChat.Component, appid: "fakecomponentappid"
  end

  defmodule Test2.Component do
    use WeChat.Component
  end

  setup_all do
    [impl_api_toml_path] = WeChat.__info__(:attributes)[:external_resource]
    toml_configs = Toml.decode_file!(impl_api_toml_path, keys: :atoms)
    [impl_component_api_toml_path] = WeChat.Component.__info__(:attributes)[:external_resource]
    component_toml_configs = Toml.decode_file!(impl_component_api_toml_path, keys: :atoms)
    {:ok, toml_configs: toml_configs, component_toml_configs: component_toml_configs}
  end

  test "validate generate functions for common wechat no required input appid", state do
    wechat_functions = Test1.__info__(:functions)

    for {func_name, configs} <- state.toml_configs do
      func_arity_list = Keyword.get_values(wechat_functions, func_name)

      http_methods = Map.get(configs, :http_verbs, []) |> Enum.sort()
      with_form_data = Map.get(configs, :with_form_data, false)

      if with_form_data do
        assert func_arity_list == [1, 2, 3]
      else
        if func_name == :token do
          assert func_arity_list == []
        else
          case http_methods do
            ["post"] ->
              assert func_arity_list == [2, 3]
            ["get"] ->
              assert func_arity_list == [1, 2, 3]
            ["get", "post"] ->
              assert func_arity_list == [1, 2, 3]
            [] ->
              assert func_arity_list == [1, 2, 3]
          end
        end
      end
    end
  end

  test "validate generate functions for common wechat required input appid", state do
    wechat_functions = Test2.__info__(:functions)

    for {func_name, configs} <- state.toml_configs do
      func_arity_list = Keyword.get_values(wechat_functions, func_name)

      http_methods = Map.get(configs, :http_verbs, []) |> Enum.sort()
      with_form_data = Map.get(configs, :with_form_data, false)

      if with_form_data do
        assert func_arity_list == [2, 3, 4]
      else
        if func_name == :token do
          assert func_arity_list == []
        else
          case http_methods do
            ["post"] ->
              assert func_arity_list == [3, 4]
            ["get"] ->
              assert func_arity_list == [2, 3, 4]
            ["get", "post"] ->
              assert func_arity_list == [2, 3, 4]
            [] ->
              assert func_arity_list == [2, 3, 4]
          end
        end
      end
    end
  end

  test "validate generate functions form component wechat no required input appid", state do
    wechat_component_functions = Test1.Component.__info__(:functions)

    for {func_name, configs} <- state.component_toml_configs do
      func_arity_list = Keyword.get_values(wechat_component_functions, func_name)
      http_methods = Map.get(configs, :http_verbs, []) |> Enum.sort()
      with_form_data = Map.get(configs, :with_form_data, false)

      cond do
        with_form_data == true ->
          assert func_arity_list == [2, 3]
        func_name == :token ->
          assert func_arity_list == []
        true ->
          case http_methods do
            ["post"] ->
              assert func_arity_list == [2, 3]
            ["get"] ->
              assert func_arity_list == [1, 2, 3]
            ["get", "post"] ->
              assert func_arity_list == [1, 2, 3]
            [] ->
              assert func_arity_list == [1, 2, 3]
          end
      end
    end

    for {func_name, configs} <- state.toml_configs do
      func_arity_list = Keyword.get_values(wechat_component_functions, func_name)
      http_methods = Map.get(configs, :http_verbs, []) |> Enum.sort()
      with_form_data = Map.get(configs, :with_form_data, false)

      cond do
        with_form_data == true ->
          assert func_arity_list == [2, 3, 4]
        func_name == :token ->
          assert func_arity_list == []
        true ->
          case http_methods do
            ["post"] ->
              assert func_arity_list == [3, 4]
            ["get"] ->
              assert func_arity_list == [2, 3, 4]
            ["get", "post"] ->
              assert func_arity_list == [2, 3, 4]
            [] ->
              assert func_arity_list == [2, 3, 4]
          end
      end
    end
  end

  test "validate generate functions for component wechat with appid", state do
    wechat_component_functions = Test2.Component.__info__(:functions)

    for {func_name, configs} <- state.component_toml_configs do
      func_arity_list = Keyword.get_values(wechat_component_functions, func_name)
      http_methods = Map.get(configs, :http_verbs, []) |> Enum.sort()
      with_form_data = Map.get(configs, :with_form_data, false)

      cond do
        with_form_data == true ->
          assert func_arity_list == [3, 4]
        func_name == :token ->
          assert func_arity_list == []
        true ->
          case http_methods do
            ["post"] ->
              assert func_arity_list == [3, 4]
            ["get"] ->
              assert func_arity_list == [2, 3, 4]
            ["get", "post"] ->
              assert func_arity_list == [2, 3, 4]
            [] ->
              assert func_arity_list == [2, 3, 4]
          end
      end
    end

    for {func_name, configs} <- state.toml_configs do
      func_arity_list = Keyword.get_values(wechat_component_functions, func_name)
      http_methods = Map.get(configs, :http_verbs, []) |> Enum.sort()
      with_form_data = Map.get(configs, :with_form_data, false)

      cond do
        with_form_data == true ->
          assert func_arity_list == [3, 4, 5]
        func_name == :token ->
          assert func_arity_list == []
        true ->
          case http_methods do
            ["post"] ->
              assert func_arity_list == [4, 5]
            ["get"] ->
              assert func_arity_list == [3, 4, 5]
            ["get", "post"] ->
              assert func_arity_list == [3, 4, 5]
            [] ->
              assert func_arity_list == [3, 4, 5]
          end
      end
    end
  end

end
