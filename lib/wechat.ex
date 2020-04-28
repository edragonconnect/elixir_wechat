defmodule WeChat do
  alias WeChat.Http
  alias WeChat.{Utils, Request}

  @type method :: :head | :get | :delete | :trace | :options | :post | :put | :patch

  defmacro __using__(opts \\ []) do
    opts = Macro.prewalk(opts, &Macro.expand(&1, __CALLER__))

    quote do
      require Logger

      @opts unquote(opts)

      @spec request(method :: WeChat.method(), options :: Keyword.t()) ::
              {:ok, term()} | {:error, WeChat.Error.t()}
      def request(method, options) do
        default_opts = Keyword.take(unquote(opts), [:adapter_storage, :appid, :authorizer_appid])
        options = WeChat.Utils.merge_keyword(options, default_opts)
        WeChat.common_request(method, options)
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
    |> check_adapter_storage(:all)
    |> setup_httpclient()
    |> send_request()
  end

  @doc false
  def common_request(method, options) do
    method
    |> prepare_request(options)
    |> check_adapter_storage(:common)
    |> setup_httpclient()
    |> send_request()
  end

  @doc false
  def component_request(method, options) do
    method
    |> prepare_request(options)
    |> check_adapter_storage(:component)
    |> setup_httpclient()
    |> send_request()
  end

  defp prepare_request(method, options) do
    uri =
      options
      |> Keyword.get(:url, [])
      |> Utils.parse_uri(Keyword.take(options, [:host, :scheme, :port]))

    %Request{
      method: check_method_opt(method),
      uri: uri,
      appid: options[:appid],
      authorizer_appid: options[:authorizer_appid],
      body: options[:body],
      query: options[:query],
      opts: options[:opts],
      adapter_storage: options[:adapter_storage]
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

  defp ensure_implements(module, available_adapter_storage_behaviours) when is_list(available_adapter_storage_behaviours) do

    matched =
      module.__info__(:attributes)
      |> Keyword.get(:behaviour, [])
      |> Enum.count(fn(behaviour) ->
        Enum.member?(available_adapter_storage_behaviours, behaviour)
      end)

    if matched != 1 do
      raise %WeChat.Error{
        reason: :invalid_adapter_storage_impl,
        message: "Please ensure module: #{inspect(module)} implemented one of #{inspect(available_adapter_storage_behaviours)} adapter storage behaviour"
      }
    end
  end

  defp check_adapter_storage(request, :all) do
    adapter_storage = do_check_adapter_storage(request.adapter_storage, :all)
    Map.put(request, :adapter_storage, adapter_storage)
  end
  defp check_adapter_storage(request, :common) do
    adapter_storage = do_check_adapter_storage(request.adapter_storage, :common)
    Map.put(request, :adapter_storage, adapter_storage)
  end
  defp check_adapter_storage(request, :component) do
    adapter_storage = do_check_adapter_storage(request.adapter_storage, :component)
    Map.put(request, :adapter_storage, adapter_storage)
  end

  defp do_check_adapter_storage({adapter_storage, args}, :all) when is_atom(adapter_storage) and is_list(args) do
    ensure_implements(
      adapter_storage,
      [
        WeChat.Storage.Client,
        WeChat.Storage.Hub,
        WeChat.Storage.ComponentClient,
        WeChat.Storage.ComponentHub
      ]
    )
    {adapter_storage, args}
  end
  defp do_check_adapter_storage(adapter_storage, :all) when is_atom(adapter_storage) do
    ensure_implements(
      adapter_storage,
      [
        WeChat.Storage.Client,
        WeChat.Storage.Hub,
        WeChat.Storage.ComponentClient,
        WeChat.Storage.ComponentHub
      ]
    )
    {adapter_storage, []}
  end
  defp do_check_adapter_storage(invalid, :all) do
    raise %WeChat.Error{
      reason: :invalid_adapter_storage_impl,
      message: "Using unexpected #{inspect(invalid)} adapter storage, please use it as one of [`WeChat.Storage.Client`, `WeChat.Storage.Hub`, `WeChat.Storage.ComponentClient`, `WeChat.Storage.ComponentHub`]"
    }
  end
  defp do_check_adapter_storage({:default, hub_base_url}, :common) when is_bitstring(hub_base_url) do
    {WeChat.Storage.Adapter.DefaultClient, [hub_base_url: hub_base_url]}
  end
  defp do_check_adapter_storage(adapter_storage, :common) when is_atom(adapter_storage) do
    ensure_implements(
      adapter_storage,
      [
        WeChat.Storage.Client,
        WeChat.Storage.Hub
      ]
    )
    {adapter_storage, []}
  end
  defp do_check_adapter_storage({adapter_storage, args}, :common) when is_atom(adapter_storage) and is_list(args) do
    ensure_implements(
      adapter_storage,
      [
        WeChat.Storage.Client,
        WeChat.Storage.Hub
      ]
    )
    {adapter_storage, args}
  end
  defp do_check_adapter_storage(invalid, :common) do
    raise %WeChat.Error{
      reason: :invalid_adapter_storage_impl,
      message: "Using unexpected #{inspect(invalid)} adapter storage, please use it as `WeChat.Storage.Client` or `WeChat.Storage.Hub`"
    }
  end
  defp do_check_adapter_storage({:default, hub_base_url}, :component) when is_bitstring(hub_base_url) do
    {WeChat.Storage.Adapter.DefaultComponentClient, [hub_base_url: hub_base_url]}
  end
  defp do_check_adapter_storage(adapter_storage, :component) when is_atom(adapter_storage) do
    ensure_implements(
      adapter_storage,
      [
        WeChat.Storage.ComponentClient,
        WeChat.Storage.ComponentHub
      ]
    )
    {adapter_storage, []}
  end
  defp do_check_adapter_storage({adapter_storage, args}, :component) when is_atom(adapter_storage) and is_list(args) do
    ensure_implements(
      adapter_storage,
      [
        WeChat.Storage.ComponentClient,
        WeChat.Storage.ComponentHub
      ]
    )
    {adapter_storage, args}
  end
  defp do_check_adapter_storage(invalid, :component) do
    raise %WeChat.Error{
      reason: :invalid_adapter_storage_impl,
      message: "Using unexpected #{inspect(invalid)} adapter storage, please use it as `WeChat.Storage.ComponentClient` or `WeChat.Storage.ComponentHub`"
    }
  end

  defp check_method_opt(method)
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

  defp check_method_opt(method) do
    raise %WeChat.Error{
      reason: :invalid_request,
      message: "Input invalid method: #{inspect(method)}"
    }
  end

end
