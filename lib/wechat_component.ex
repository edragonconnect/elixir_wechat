defmodule WeChat.Component do
  @moduledoc false

  require Logger

  defmacro __using__(opts \\ []) do
    default_opts =
      opts
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> Keyword.take([:adapter_storage, :appid, :authorizer_appid])

    quote do

      def default_opts, do: unquote(default_opts)

      @doc """
      See WeChat.request/2 for more information.
      """
      def request(method, options) do
        options = WeChat.Utils.merge_keyword(options, unquote(default_opts))
        WeChat.component_request(method, options)
      end

      defoverridable default_opts: 0, request: 2
    end
  end

end
