defmodule WeChat.Utils do
  use Timex

  @random_alphanumeric Enum.concat([?a..?z, ?A..?Z, 48..57])

  alias WeChat.JSSDKSignature

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
    str_to_sign = "jsapi_ticket=#{jsapi_ticket}&noncestr=#{noncestr}&timestamp=#{timestamp}&url=#{url}"
    signature = :crypto.hash(:sha, str_to_sign) |> Base.encode16(case: :lower)
    %JSSDKSignature{value: signature, timestamp: timestamp, noncestr: noncestr}
  end

end
