# ElixirWeChat

[![hex.pm](https://img.shields.io/hexpm/v/elixir_wechat.svg)](https://hex.pm/packages/elixir_wechat)
[![hex.pm](https://img.shields.io/hexpm/dt/elixir_wechat.svg)](https://hex.pm/packages/elixir_wechat)
[![hex.pm](https://img.shields.io/hexpm/l/elixir_wechat.svg)](https://hex.pm/packages/elixir_wechat)
[![github.com](https://img.shields.io/github/last-commit/edragonconnect/elixir_wechat.svg)](https://github.com/edragonconnect/elixir_wechat)

Elixir API wrapper for [WeChat](https://www.wechat.com/).

## Introduction

At present, there are two ways to build application in WeChat Official Account
open ecosystem:

* Integrates public APIs after turn on your WeChat Official Account into the developer mode ([see details](https://developers.weixin.qq.com/doc/offiaccount/en/Basic_Information/Access_Overview.html)), here named it as `common` application in document of `elixir_wechat`, the same below;

* Authorizes your WeChat Official Account to the WeChat Official Account third-party platform application ([see details](https://developers.weixin.qq.com/doc/oplatform/en/Third-party_Platforms/Third_party_platform_appid.html)), here named it as `component` application in document of `elixir_wechat`, the same below.

This library wants to provide a flexible way to explicitly call all of
WeChat's API functions, meanwhile helps to maintain the fetch-expiry-refresh
loop cycle of `access_token`, you can choose your way to storage
`access_token`, `jssdk-ticket` and `card-ticket` as well.

## Background

Refer the official
[document](https://developers.weixin.qq.com/doc/offiaccount/en/Basic_Information/Get_access_token.html)'s
recommend there needs the centralization nodes to maintain the life cycle of
`access_token` (fetch/storage/refresh).

This library is designed for these four use scenarios:

| Application | Scenario | Storage Behaviour |
| -------- | ----------- | --------- |
| `common` | *client* | `WeChat.Storage.Client` |
| `common` | *hub* | `WeChat.Storage.Hub` |
| `component` | *client* | `WeChat.Storage.ComponentClient` |
| `component` | *hub* | `WeChat.Storage.ComponentHub` |

Notice:

* The above "*client*" means the business logic which rely on the
  `access_token` maintained by the centralization nodes;

* The above "*hub*" means the implements in the centralization nodes.

## How to use

### Install

```elixir
def deps do
  [
   {:elixir_wechat, "~> 0.4"}
  ]
end
```

### Http Client

Currently, this library uses `Tesla.Adapter.Finch` to process http request/response, you can optionally define Finch's 
default pool setting like this:

```
config :elixir_wechat,
  pool_size: 100,
  pool_count: 1
```

* `pool_size`, optional, number of connections to maintain in each pool, see `Finch.request/6` for details, default to 100.
* `pool_count`, optional, number of pools to start, see `Finch.request/6` for details, default to 1.

### Usage

First of all, let's add the built-in plug into the router of your server:

```
plug WeChat.Plug.Pipeline,
  adapter_storage: [
    component: WeChat.Storage.ComponentLocal,
    common: WeChat.Storage.Local
  ]
```

The `adapter_storage` option is required, according to your use case, you need
to implement your `common` or `component` storage refer the corresponding
behaviour, if your server need to cover both of them, just add them as the same
time.

After the above setup, there will add the following URLs into your server for
internal interactive, both of them are used to read/write cacheable data from
the centralization nodes.

```
POST "/refresh/access_token"
GET "/client/access_token"
GET "/client/component_access_token"
GET "/client/ticket"
```

For example, assume that the above setup server is running as
"http://localhost:4000", now let's invoke the [get material list](https://developers.weixin.qq.com/doc/offiaccount/Asset_Management/Get_materials_list.html)
API as an example from the `client` side.

```text
POST /cgi-bin/material/batchget_material?access_token=ACCESS_TOKEN
Host: api.weixin.qq.com
Scheme: https

Body: {
  "type": "image",
  "offset": 0,
  "count": 10
}
```

#### As a `common` client application

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

#### As a `component` client application

```elixir
defmodule MyComponentClient do
  use WeChat.Component,
    adapter_storage: {:default, "http://localhost:4000"},
    appid: "MyComponentAppID",
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
  appid: "MyComponentAppID",
  authorizer_appid: "MyAuthorizerAppID",
  adapter_storage: {:default, "http://localhost:4000"},
  url: "/cgi-bin/material/batchget_material",
  body: %{type: "image", offset: 0, count: 10}
)
```

Please notice the `access_token` parameter will be automatically appended by
this library, if `access_token` is expired when calling, there will retry
refresh `access_token` from self-host centralization nodes, and then self-host
centralization nodes will maintain the life cycle of a fresh `access_token`.

The default adapter storage `{:default, "http://localhost:4000"}` is
implemented as a client connects to the self-host hub servers via some predefined HTTP API
functions:
  
  * The `WeChat.Storage.Adapter.DefaultClient` is used for `common` application.
  * The `WeChat.Storage.Adapter.DefaultComponentClient` is used for `component` application.

In **general** use, you need to define your adapter storage implemented the
corresponding behaviour, the aim of this design to adapt as much as you want.

## Document

```bash
$ mix docs
```

## Test

First you need to add the following environment variables in the
`config/test.exs`, and then run `mix test` in the root of this repo.

```elixir
System.put_env("TEST_COMMON_APPID", "...")
System.put_env("TEST_COMPONENT_APPID", "...")
System.put_env("TEST_HUB_URL", "...")
System.put_env("TEST_OPENID", "...")
```

## License

MIT
