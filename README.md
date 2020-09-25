# Elixir for WeChat

## Introduce

At present, there are two ways to build application in WeChat Official Account open ecosystem:

* Integrates public APIs after trun on your WeChat Official Account into the developer mode ([see details](https://developers.weixin.qq.com/doc/offiaccount/en/Basic_Information/Access_Overview.html)), here named it as `common` application in document of `elixir_wechat`, the same below;
* Authorizes your WeChat Official Account to the WeChat Official Account third-party platform application ([see details](https://developers.weixin.qq.com/doc/oplatform/en/Third-party_Platforms/Third_party_platform_appid.html)), here named it as `component` application in document of `elixir_wechat`, the same below.

This library wants to provide a flexible way to explicitly call **ALL** of WeChat's API functions, meanwhile helps to maintain the fetch-expiry-refresh loop cycle of `access_token`, you can choose your way to
storage `access_token`, `jssdk-ticket` and `card-ticket` as well.

## Background

Refer the official [document](https://developers.weixin.qq.com/doc/offiaccount/en/Basic_Information/Get_access_token.html)'s recommend there needs the centralization nodes to maintain the lifecycle of `access_token` (storage/refresh/fetch).

This library is designed for these four use scenarios:

| Application | Scenario | Storage Behaviour |
| -------- | ----------- | --------- |
| `common` | *client* | `WeChat.Storage.Client` |
| `common` | *hub* | `WeChat.Storage.Hub` |
| `component` | *client* | `WeChat.Storage.ComponentClient` |
| `component` | *hub* | `WeChat.Storage.ComponentHub` |

Notice:

* The above "*client*" means the business logic which rely on the `access_token` maintained by the centralization nodes;
* The above "*hub*" means the implements in the centralization nodes.

## How to use

### Install

```elixir
def deps do
  [
   {:elixir_wechat, "~> 0.2"}
  ]
end
```

### Usage

First of all, let's add the built-in plug into the router of your server:

```
plug WeChat.Plug.Pipeline,
  adapter_storage: [
    component: WeChat.Storage.ComponentLocal,
    common: WeChat.Storage.Local
  ]
```

The `adapter_storage` option is required, according to your use case, you need to implement your `common` or `component` storage refer the corresponding behaviour, if your server need to cover both of them, just add them as the same time.

After the above setup, there will add the following urls into your server for internal interactive, both of them are used to read/write cacheable data from the centralization nodes.

```
POST "/refresh/access_token"
GET "/client/access_token"
GET "/client/component_access_token"
GET "/client/ticket"
```

For example, assume that the above setup server is runing as "http://localhost:4000", now let's invoke a detailed WeChat's API as an example from the `client` side.

```
POST https://api.weixin.qq.com/cgi-bin/material/batchget_material

"Query Params":
access_token="ACCESS_TOKEN"

"Body":
{"type": "image", "offset": 0, "count": 10}
``` 

#### As `common` client application

```elixir
defmodule MyClient do
  use WeChat,
    adapter_storage: {:default, "http://localhost:4000"},
    appid: "MyAppID"
end

MyClient.request(
  :post, 
  url: "/cgi-bin/material/batchget_material",
  body: %{type: "image", offset: 0, count: 10}
)
```

Or use `WeChat.request/2` directly

```elixir
WeChat.request(
  :post,
  appid: "MyAppID",
  adapter_storage: {:default, "http://localhost:4000"},
  url: "/cgi-bin/material/batchget_material",
  body: %{type: "image", offset: 0, count: 10}
)
```

#### As `component` client application

```elixir
defmodule MyComponentClient do
  use WeChat.Component,
    adapter_storage: {:default, "http://localhost:4000"},
    appid: "MyAppID",
    authorizer_appid: "MyAuthorizerAppID"
end

MyComponentClient.request(
  :post,
  url: "/cgi-bin/material/batchget_material",
  body: %{type: "image", offset: 0, count: 10}
)
```

Or use `WeChat.request/2` directly

```elixir
WeChat.request(
  :post,
  appid: "MyAppID",
  authorizer_appid: "MyAuthorizerAppID",
  adapter_storage: {:default, "http://localhost:4000"},
  url: "/cgi-bin/material/batchget_material",
  body: %{type: "image", offset: 0, count: 10}
)
```

Please notice the `access_token` parameter will be automatically appended by this library, if `access_token` is expired when calling, there will retry refresh `access_token` from self-host centralization nodes, and then self-host centralization nodes will maintain the lifecycle of a fresh `access_token`.

The default adapter storage `{:default, "http://localhost:4000"}` is implemented as a client to the hub server(s) via some predefined HTTP API functions, the `WeChat.Storage.Adapter.DefaultClient` is used for `common` application, and the `WeChat.Storage.Adapter.DefaultComponentClient` is used for `component` application.

In **general** use, you need to define your adapter storage implemented the corresponding behaviour, the aim of this design to adapt as much as you want.

## Document

```bash
$ mix docs
```

## Test

First you need to add the following environment variables in the `config/test.exs`,
and then run `mix test` in the root of this repo.

```elixir
System.put_env("TEST_COMMON_APPID", "...")
System.put_env("TEST_COMPONENT_APPID", "...")
System.put_env("TEST_HUB_URL", "...")
System.put_env("TEST_OPENID", "...")
```

## Lincese

MIT
