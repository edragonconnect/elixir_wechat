if Code.ensure_loaded?(Plug) do
  defmodule WeChat.Plug.Pipeline do
    @moduledoc false

    use Plug.Builder
    require Logger

    plug(WeChat.Plug.Router, builder_opts())
  end
end
