defmodule WeChat do
  alias WeChat.Http
  alias WeChat.{Utils, Request}

  @type method :: :head | :get | :delete | :trace | :options | :post | :put | :patch

  defmacro __using__(opts \\ []) do
    opts =
      opts
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> initialize_opts()

    quote do
      require Logger

      @opts unquote(opts)

      @spec request(method :: WeChat.method(), options :: Keyword.t()) ::
              {:ok, term()} | {:error, WeChat.Error.t()}
      def request(method, options) do
        options = WeChat.Utils.merge_keyword(options, @opts)
        WeChat.request(method, options)
      end
    end
  end

  defmodule Error do
    @moduledoc false

    @derive {Jason.Encoder, only: [:errcode, :message, :reason, :http_status]}
    defexception errcode: nil, message: nil, reason: nil, http_status: nil

    def message(%__MODULE__{
          errcode: errcode,
          message: message,
          reason: reason,
          http_status: http_status
        }) do
      "errcode: #{inspect(errcode)}, message: #{inspect(message)}, reason: #{inspect(reason)}, http_status: #{
        inspect(http_status)
      }"
    end
  end

  defmodule Request do
    @moduledoc false

    @type body :: {:form, map()} | map()

    @type t :: %__MODULE__{
            method: atom(),
            uri: URI.t(),
            appid: String.t(),
            authorizer_appid: String.t(),
            adapter_storage: module(),
            body: body(),
            use_case: atom(),
            query: keyword(),
            opts: keyword(),
            access_token: String.t()
          }

    defstruct [
      :method,
      :uri,
      :appid,
      :authorizer_appid,
      :adapter_storage,
      :body,
      :use_case,
      :query,
      :opts,
      :access_token
    ]
  end

  defmodule Token do
    @type t :: %__MODULE__{
            access_token: String.t(),
            refresh_token: String.t()
          }
    defstruct [:access_token, :refresh_token]
  end

  defmodule UploadMedia do
    @moduledoc """
    TODO
    """
    @type t :: %__MODULE__{
            file_path: String.t(),
            type:
              {:image, String.t()}
              | {:voice, String.t()}
              | {:video, String.t()}
              | {:thumb, String.t()}
          }
    @enforce_keys [:file_path, :type]
    defstruct [:file_path, :type]
  end

  defmodule UploadMediaContent do
    @moduledoc """
    TODO
    """
    @type t :: %__MODULE__{
            file_content: binary(),
            file_name: String.t(),
            type:
              {:image, String.t()}
              | {:voice, String.t()}
              | {:video, String.t()}
              | {:thumb, String.t()}
          }
    @enforce_keys [:file_content, :file_name, :type]
    defstruct [:file_content, :file_name, :type]
  end

  defmodule JSSDKSignature do
    @type t :: %__MODULE__{
            value: String.t(),
            timestamp: integer(),
            noncestr: String.t()
          }
    defstruct [:value, :timestamp, :noncestr]
  end

  defmodule CardSignature do
    @type t :: %__MODULE__{
            value: String.t(),
            timestamp: integer(),
            noncestr: String.t()
          }
    defstruct [:value, :timestamp, :noncestr]
  end

  @doc """
  To configure and load WeChat JSSDK in the target page's url properly, use `jsapi_ticket` and `url` to generate a signature for this scenario.
  """
  @spec sign_jssdk(jsapi_ticket :: String.t(), url :: String.t()) :: JSSDKSignature.t()
  defdelegate sign_jssdk(jsapi_ticket, url), to: Utils

  @doc """
  To initialize WeChat Card functions in JSSDK, use `wxcard_ticket` and `card_id` to generate a signature for this scenario.
  https://developers.weixin.qq.com/doc/offiaccount/OA_Web_Apps/JS-SDK.html#65
  """
  @spec sign_card(list :: [String.t()]) :: CardSignature.t()
  @spec sign_card(wxcard_ticket :: String.t(), card_id :: String.t()) :: CardSignature.t()
  @spec sign_card(wxcard_ticket :: String.t(), card_id :: String.t(), openid :: String.t()) ::
          CardSignature.t()
  defdelegate sign_card(wxcard_ticket, card_id), to: Utils
  defdelegate sign_card(wxcard_ticket, card_id, openid), to: Utils
  defdelegate sign_card(list), to: Utils

  @doc """

  ## Options

  - `:appid`,
  - `:url`,
  - `:authorizer_appid`,
  - `:adapter_storage`,
  - `:body`,
  - `:query`,
  - `:opts`

  """
  @spec request(method :: method(), options :: Keyword.t()) ::
          {:ok, term()} | {:error, WeChat.Error.t()}
  def request(method, options) do
    method
    |> prepare_request(options)
    |> setup_httpclient()
    |> send_request()
  end

  defp prepare_request(method, options) do
    uri =
      options
      |> Keyword.get(:url, [])
      |> Utils.parse_uri(Keyword.take(options, [:host, :scheme, :port]))

    %Request{
      method: prepare_method_opt(method),
      uri: uri,
      appid: options[:appid],
      authorizer_appid: options[:authorizer_appid],
      adapter_storage: options[:adapter_storage],
      body: options[:body],
      use_case: options[:use_case],
      query: options[:query],
      opts: options[:opts]
    }
  end

  defp setup_httpclient(%Request{uri: %URI{path: path}}) when path == "" or path == nil do
    raise %WeChat.Error{reason: :invalid_request, message: "Input invalid url"}
  end

  defp setup_httpclient(%Request{uri: %URI{path: "/cgi-bin/component" <> _}} = request) do
    {Http.component_client(request), request}
  end

  defp setup_httpclient(%Request{uri: %URI{path: "cgi-bin/component" <> _}} = request) do
    {Http.component_client(request), request}
  end

  defp setup_httpclient(request) do
    {Http.client(request), request}
  end

  defp send_request({client, request}) do
    options = [
      method: request.method,
      url: URI.to_string(request.uri),
      query: request.query,
      body: request.body,
      opts: request.opts
    ]

    Http.request(client, options)
  end

  @doc false
  def ensure_implements(module, behaviour) do
    all = Keyword.take(module.__info__(:attributes), [:behaviour])

    unless [behaviour] in Keyword.values(all) do
      raise %WeChat.Error{
        reason: :invalid_impl,
        message:
          "Require #{inspect(module)} to implement adapter storage #{inspect(behaviour)} behaviour."
      }
    end
  end

  defp initialize_opts(opts) do
    use_case = Keyword.get(opts, :use_case, :client)

    Keyword.merge(opts,
      adapter_storage: map_adapter_storage(use_case, opts[:adapter_storage]),
      use_case: use_case,
      appid: opts[:appid],
      authorizer_appid: opts[:authorizer_appid]
    )
  end

  defp map_adapter_storage(:client, {:default, hub_base_url}) when is_bitstring(hub_base_url) do
    {WeChat.Storage.Adapter.DefaultClient, [hub_base_url: hub_base_url]}
  end

  defp map_adapter_storage(:client, adapter_storage) when is_atom(adapter_storage) do
    ensure_implements(adapter_storage, WeChat.Storage.Client)
    {adapter_storage, []}
  end

  defp map_adapter_storage(:client, {adapter_storage, args}) when is_atom(adapter_storage) and is_list(args) do
    ensure_implements(adapter_storage, WeChat.Storage.Client)
    {adapter_storage, args}
  end

  defp map_adapter_storage(:hub, adapter_storage) when is_atom(adapter_storage) do
    ensure_implements(adapter_storage, WeChat.Storage.Hub)
    {adapter_storage, []}
  end

  defp map_adapter_storage(:hub, {adapter_storage, args}) when is_atom(adapter_storage) and is_list(args) do
    ensure_implements(adapter_storage, WeChat.Storage.Hub)
    {adapter_storage, args}
  end

  defp prepare_method_opt(method)
       when method == :head
       when method == :get
       when method == :delete
       when method == :trace
       when method == :options
       when method == :post
       when method == :put
       when method == :patch do
    method
  end

  defp prepare_method_opt(method) do
    raise %WeChat.Error{
      reason: :invalid_request,
      message: "Input invalid method: #{inspect(method)}"
    }
  end
end
