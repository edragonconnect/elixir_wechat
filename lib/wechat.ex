defmodule WeChat do
  @moduledoc """
  The link to WeChat Official Account Platform API document in [Chinese](https://developers.weixin.qq.com/doc/offiaccount/Getting_Started/Overview.html){:target="_blank"} | [English](https://developers.weixin.qq.com/doc/offiaccount/en/Getting_Started/Overview.html){:target="_blank"}.

  Currently, there are two ways to use the WeChat's APIs:

    * As `common` application, directly integrates WeChat's APIs after trun on your WeChat Official Account into the developer mode ([see details](https://developers.weixin.qq.com/doc/offiaccount/en/Basic_Information/Access_Overview.html){:target="_blank"});
    * As `component` application, authorizes your WeChat Official Account to the WeChat Official Account third-party platform application, leverages a set of common solutions from the third-party platform ([see details](https://developers.weixin.qq.com/doc/oplatform/en/Third-party_Platforms/Third_party_platform_appid.html){:target="_blank"}).

  Refer the official document's recommend to manage access token ([see details](https://developers.weixin.qq.com/doc/offiaccount/en/Basic_Information/Get_access_token.html){:target="_blank"}), we need to
  temporarily storage access token in a centralization way, we prepare four behaviours to manage the minimum responsibilities for each use case.

  Use this library in the 3rd-party webapp which can read the temporary storage data (e.g. access token/jsapi-ticket/card-ticket) from the centralization nodes(hereinafter "hub"):

    * The `WeChat.Storage.Client` storage adapter behaviour is required for the `common` application;
    * The `WeChat.Storage.ComponentClient` storage adapter behaviour is required for the `component` application.

  Use this library in the hub webapp:

    * The `WeChat.Storage.Hub` storage adapter behaviour is required for the `common` application;
    * The `WeChat.Storage.ComponentHub` storage adapter behaviour is required for the `component` application.

  As usual, the hub webapp is one-off setup to use this library, most of time we use `elixir_wechat` is in the 3rd-party webapp as a client, so here provide a default storage adapter to conveniently
  initialize it as a client use case:

    * The `WeChat.Storage.Adapter.DefaultClient` implements `WeChat.Storage.Client` behaviour, and is used for the `common` application by default:

      ```elixir
      defmodule MyClient do
        use WeChat,
          adapter_storage: {:default, "MyHubBaseURL"}
      end

      # the above equals the following
      #
      defmodule MyClient do
        use WeChat,
          adapter_storage: {WeChat.Storage.Adapter.DefaultClient, "MyHubBaseURL"}
      end
      ```

    * The `WeChat.Storage.Adapter.DefaultComponentClient` implements `WeChat.Storage.ComponentClient` behaviour, and is used for the `component` application by default:

      ```elixir
      defmodule MyComponentClient do
        use WeChat.Component,
          adapter_storage: {:default, "MyHubBaseURL"}
      end

      # the above equals the following
      #
      defmodule MyComponentClient do
        use WeChat.Component,
          adapter_storage: {WeChat.Storage.Adapter.DefaultComponentClient, "MyHubBaseURL"}
      end
      ```

  ## Usage

  ### As `common` application

  ```elixir
  defmodule MyClient do
    use WeChat,
      adapter_storage: {:default, "MyHubBaseURL"},
      appid: "MyAppID"
  end

  MyClient.request(:post, url: "WeChatURL1", body: %{}, query: [])
  MyClient.request(:get, url: "WeChatURL2", query: [])
  ```

  Or use `WeChat.request/2` directly

  ```elixir
  WeChat.request(:post, url: "WeChatURL1",
    appid: "MyAppID", adapter_storage: {:default, "MyHubBaseURL"},
    body: %{}, query: [])

  WeChat.request(:get, url: "WeChatURL2",
    appid: "MyAppID", adapter_storage: {:default, "MyHubBaseURL"},
    query: [])
  ```

  ### As `component` application

  ```elixir
  defmodule MyComponentClient do
    use WeChat.Component,
      adapter_storage: {:default, "MyHubBaseURL"},
      appid: "MyAppID",
      authorizer_appid: "MyAuthorizerAppID"
  end

  MyComponentClient.request(:post, url: "WeChatURL1", body: %{}, query: [])
  MyComponentClient.request(:post, url: "WeChatURL2", query: [])
  ```

  Or use `WeChat.request/2` directly

  ```elixir
  WeChat.request(:post, url: "WeChatURL1",
    appid: "MyAppID", authorizer_appid: "MyAuthorizerAppID",
    adapter_storage: {:default, "MyHubBaseURL"}, body: %{}, query: [])

  WeChat.request(:get, url: "WeChatURL2",
    appid: "MyAppID", authorizer_appid: "MyAuthorizerAppID",
    adapter_storage: {:default, "MyHubBaseURL"}, query: [])
  ```
  """

  alias WeChat.{Http, Utils}

  @type method :: :head | :get | :delete | :trace | :options | :post | :put | :patch
  @type error :: atom() | WeChat.Error.t()

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
      @spec request(method :: WeChat.method(), options :: Keyword.t()) ::
              {:ok, term()} | {:error, WeChat.error()}
      def request(method, options) do
        options = WeChat.Utils.merge_keyword(options, unquote(default_opts))
        WeChat.common_request(method, options)
      end

      defoverridable request: 2
    end
  end

  defmodule Error do
    @moduledoc """
    A WeChat error expression.
    """

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
    @moduledoc false
    @type t :: %__MODULE__{
            access_token: String.t(),
            refresh_token: String.t()
          }

    @derive Jason.Encoder
    defstruct [:access_token, :refresh_token]
  end

  defmodule UploadMedia do
    @moduledoc """
    Use for upload media file related.
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
    Use for upload media file content related.
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
    @moduledoc """
    A WeChat JSSDK signature expression.
    """
    @type t :: %__MODULE__{
            value: String.t(),
            timestamp: integer(),
            noncestr: String.t()
          }
    defstruct [:value, :timestamp, :noncestr]
  end

  defmodule CardSignature do
    @moduledoc """
    A WeChat Card signature expression.
    """
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
  Call WeChat's HTTP API functions in a explicit way.

  We can defined a global module to assemble `appid`, `authorizer_appid`(only used for "component" application), and `adapter_storage`.

  For example:

  ```
  defmodule MyClient do
    use WeChat,
      appid: "...",
      adapter_storage: "..."
  end
  ```

  ```
  defmodule MyComponentClient do
    use WeChat.Component,
      appid: "...",
      authorizer_appid: "...",
      adapter_storage: "..."
  end
  ```

  And then we can use `MyClient` or `MyComponentClient` to call `request/2`, as usual, there dose NOT need to pass the above parameters when invoke, but if needed you
  input them to override.

  We can directly use `WeChat.request/2` as well, in this way, the `appid`, `authorizer_appid`(only used for "component" application), and `adapter_storage` are required
  for each invoke.

  The `method` parameter can be used as one of `t:method/0`.

  ## Options

  - `:appid`, required, if you use a global module to assemble it, this value is optional. If you are using a `common` application, `appid` means the application id of your 
  WeChat Official Account; if you are a `component` application, `appid` means the application id of your WeChat Official Account third-party platform application.
  - `:authorizer_appid`, optional, if you are using a `component` application, this value is required, the application id of your WeChat Official Account third-party platform
  application.
  - `:adapter_storage`, required, the predefined storage way to used for `access_token`, `jsapi_ticket`, and `card_ticket`, here provide a `{:default, "MyHubURL"}` as option.
  - `:url`, required, the URL to call WeChat's HTTP API function, for example, "/cgi-bin/material/get_materialcount", also you can input a completed URL like
  this "https://api.weixin.qq.com/cgi-bin/material/get_materialcount".
  - `:host`, optional, the host of URI to call WeChat's HTTP API function, if you input a completed URL with host, this value is optional, by default it is "api.weixin.qq.com".
  - `:scheme`, optional, the scheme of URI to call WeChat's HTTP API function, if you input a completed URL with scheme, this value is optional, by default it is "https".
  - `:port`, optional, the port of URI to call WeChat's HTTP API function, if you input a completed URL with port, this value is optional, by default it is "443"(as integer).
  - `:body`, optional, a map, decided by your used WeChat's HTTP API functions, following WeChat official document to setup the body of the request.
  - `:query`, optional, a keyword, decided by your used WeChat's HTTP API functions, following WeChat official document to setup the query string of the request, this library will
  automatically appended a proper `access_token` into the query of each request, so we do NOT need to input `access_token` parameter.
  - `:opts`, optional, custom, per-request middleware or adapter options (exported from `Tesla`)
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

  def fetch_access_token(appid, adapter_storage) when is_atom(adapter_storage) do
    fetch_access_token(appid, {adapter_storage, nil})
  end

  def fetch_access_token(appid, {adapter_storage, args}) do
    token = adapter_storage.fetch_access_token(appid, args)

    case token do
      {:ok, %WeChat.Token{access_token: access_token}} when access_token != nil ->
        token

      _ ->
        refetch_access_token(appid, adapter_storage, args)
    end
  end

  defp prepare_request(method, options) do
    uri = Utils.parse_uri(options[:url], Keyword.take(options, [:host, :scheme, :port]))

    query = options[:query] || []

    appid = options[:appid] || Keyword.get(query, :appid)

    %Request{
      method: check_method_opt(method),
      uri: uri,
      appid: appid,
      authorizer_appid: options[:authorizer_appid],
      body: options[:body],
      query: query,
      opts: options[:opts],
      adapter_storage: options[:adapter_storage]
    }
  end

  defp setup_httpclient(%Request{uri: %URI{path: path}}) when path == "" or path == nil do
    raise %WeChat.Error{reason: :invalid_request, message: "url is required"}
  end

  defp setup_httpclient(%Request{uri: %URI{path: "/cgi-bin/component" <> _}} = request) do
    {Http.component_client(request), request}
  end

  defp setup_httpclient(%Request{uri: %URI{path: "cgi-bin/component" <> _}} = request) do
    {Http.component_client(request), request}
  end

  defp setup_httpclient(%Request{uri: %URI{path: "/sns/oauth2/component/" <> _}} = request) do
    {Http.component_client(request), request}
  end

  defp setup_httpclient(%Request{uri: %URI{path: "sns/oauth2/component/" <> _}} = request) do
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

  defp ensure_implements(module, available_adapter_storage_behaviours)
       when is_list(available_adapter_storage_behaviours) do
    matched =
      module.__info__(:attributes)
      |> Keyword.get(:behaviour, [])
      |> Enum.count(fn behaviour ->
        Enum.member?(available_adapter_storage_behaviours, behaviour)
      end)

    if matched != 1 do
      raise %WeChat.Error{
        reason: :invalid_config,
        message:
          "please ensure module: #{inspect(module)} implemented one of #{
            inspect(available_adapter_storage_behaviours)
          } adapter storage behaviour"
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

  defp do_check_adapter_storage({adapter_storage, args}, :all) when is_atom(adapter_storage) do
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
      reason: :invalid_config,
      message:
        "using unexpected #{inspect(invalid)} adapter storage, please use it as one of [`WeChat.Storage.Client`, `WeChat.Storage.Hub`, `WeChat.Storage.ComponentClient`, `WeChat.Storage.ComponentHub`]"
    }
  end

  defp do_check_adapter_storage({:default, hub_base_url}, :common)
       when is_bitstring(hub_base_url) do
    {WeChat.Storage.Adapter.DefaultClient, hub_base_url}
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

  defp do_check_adapter_storage({adapter_storage, args}, :common)
       when is_atom(adapter_storage) and is_list(args) do
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
      reason: :invalid_config,
      message:
        "using unexpected #{inspect(invalid)} adapter storage, please use it as `WeChat.Storage.Client` or `WeChat.Storage.Hub`"
    }
  end

  defp do_check_adapter_storage({:default, hub_base_url}, :component)
       when is_bitstring(hub_base_url) do
    {WeChat.Storage.Adapter.DefaultComponentClient, hub_base_url}
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

  defp do_check_adapter_storage({adapter_storage, args}, :component)
       when is_atom(adapter_storage) do
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
      reason: :invalid_config,
      message:
        "using unexpected #{inspect(invalid)} adapter storage, please use it as `WeChat.Storage.ComponentClient` or `WeChat.Storage.ComponentHub`"
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
      message: "input invalid http method: #{inspect(method)}"
    }
  end

  defp refetch_access_token(appid, adapter_storage, args) do
    request_result =
      WeChat.request(
        :get,
        appid: appid,
        adapter_storage: {adapter_storage, args},
        url: "/cgi-bin/token"
      )

    case request_result do
      {:ok, %{body: %{"access_token" => access_token}}} ->
        {
          :ok,
          %WeChat.Token{access_token: access_token}
        }

      {:ok, response} ->
        raise Utils.as_error(response)

      {:error, error} ->
        raise Utils.as_error(error)
    end
  end
end
