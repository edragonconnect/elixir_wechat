defmodule WeChat.Component do
  @moduledoc false

  require Logger

  defmacro __using__(opts \\ []) do
    opts = Macro.prewalk(opts, &Macro.expand(&1, __CALLER__))

    quote do

      def request(method, options) do
        default_opts = Keyword.take(unquote(opts), [:adapter_storage, :appid, :authorizer_appid])
        options = WeChat.Utils.merge_keyword(options, default_opts)
        WeChat.component_request(method, options)
      end

    end
  end

end
