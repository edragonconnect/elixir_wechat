defmodule WeChat.Utils do
  @moduledoc false

  use Timex

  @random_alphanumeric Enum.concat([?a..?z, ?A..?Z, 48..57])

  alias WeChat.{JSSDKSignature, CardSignature}

  def random_string(length) when length > 0 do
    @random_alphanumeric
    |> Enum.take_random(length)
    |> List.to_string()
  end

  def now_unix() do
    Timex.to_unix(Timex.now())
  end

  @doc """
  To configure and load WeChat JSSDK in the target page's url properly, use `jsapi_ticket` and `url` to generate an signature for this scenario.
  """
  @spec sign_jssdk(jsapi_ticket :: String.t(), url :: String.t()) :: JSSDKSignature.t()
  def sign_jssdk(jsapi_ticket, url) do
    url = String.replace(url, ~r/\#.*/, "")
    noncestr = random_string(16)
    timestamp = now_unix()

    str_to_sign =
      "jsapi_ticket=#{jsapi_ticket}&noncestr=#{noncestr}&timestamp=#{timestamp}&url=#{url}"

    signature = :crypto.hash(:sha, str_to_sign) |> Base.encode16(case: :lower)
    %JSSDKSignature{value: signature, timestamp: timestamp, noncestr: noncestr}
  end

  @doc """
  To initialize WeChat Card functions via JSSDK, use `wxcard_ticket`, `card_id` to generate an signature for this scenario.
  https://developers.weixin.qq.com/doc/offiaccount/OA_Web_Apps/JS-SDK.html#65
  """
  @spec sign_card(list :: [String.t()]) :: CardSignature.t()
  @spec sign_card(wxcard_ticket :: String.t(), card_id :: String.t()) :: CardSignature.t()
  @spec sign_card(wxcard_ticket :: String.t(), card_id :: String.t(), openid :: String.t()) ::
          CardSignature.t()
  def sign_card(wxcard_ticket, card_id), do: sign_card([wxcard_ticket, card_id])
  def sign_card(wxcard_ticket, card_id, openid), do: sign_card([wxcard_ticket, card_id, openid])

  def sign_card(list) do
    noncestr = random_string(16)
    timestamp = now_unix()
    timestamp_str = Integer.to_string(timestamp)
    str_to_sign = Enum.sort([timestamp_str, noncestr | list]) |> Enum.join()
    signature = :crypto.hash(:sha, str_to_sign) |> Base.encode16(case: :lower)
    %CardSignature{value: signature, timestamp: timestamp, noncestr: noncestr}
  end

  @doc """
  Merges two keyword lists into one if the value to the matched key of the former(`keyword1`) is nil, will use the latter(`keyword2`)'s value to instead it.
  """
  def merge_keyword(keyword1, keyword2) do
    Keyword.merge(keyword1, keyword2, fn _k, v1, v2 ->
      if v1 == nil, do: v2, else: v1
    end)
  end

  def parse_uri(uri, opts \\ [])
  def parse_uri(nil, _opts), do: nil

  def parse_uri(uri, opts) do
    URI.parse(uri)
    |> format_uri_host(Keyword.get(opts, :host, "api.weixin.qq.com"))
    |> format_uri_scheme(Keyword.get(opts, :scheme, "https"))
    |> format_uri_port(Keyword.get(opts, :port, 443))
  end

  def json_decode(nil), do: nil
  def json_decode(""), do: nil

  def json_decode(input) do
    case Jason.decode(input) do
      {:ok, decoded} ->
        decoded

      {:error, _} ->
        input
    end
  end

  defp format_uri_host(%URI{host: nil} = uri, input_host) when is_bitstring(input_host) do
    Map.put(uri, :host, input_host)
  end

  defp format_uri_host(uri, _) do
    uri
  end

  defp format_uri_scheme(%URI{scheme: nil} = uri, input_scheme) when is_bitstring(input_scheme) do
    Map.put(uri, :scheme, input_scheme)
  end

  defp format_uri_scheme(uri, _) do
    uri
  end

  defp format_uri_port(%URI{port: nil} = uri, input_port) when is_integer(input_port) do
    Map.put(uri, :port, input_port)
  end

  defp format_uri_port(uri, _) do
    uri
  end
end
