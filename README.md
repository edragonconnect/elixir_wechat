# Elixir for WeChat

用于微信公众号开放生态环境下构建Elixir版本应用:

* 支持绝大多数 [微信公众号开放](https://mp.weixin.qq.com/wiki) 接口
* 支持 [微信第三方平台应用](https://open.weixin.qq.com/cgi-bin/showdocument?action=dir_list&t=resource/res_list&verify=1&id=open1419318292) 接口

**注意*: 目前微信支付相关接口并不保证在支持范围内。

## 背景

参考微信官方对`access_token`的指导[文档](https://mp.weixin.qq.com/wiki?t=resource/res_main&id=mp1421140183)，需要提供一种集中式（这里称为 “hub”，下同）的方式统一管理、维护（刷新）`access_token`，所以当前这个版本的SDK在设计的时候，考虑了以下几种调用微信接口的使用场景：

1. 使用该SDK直接对接某个微信公众号完成该公众号的开发

	* 直接对接某个微信公众号，该SDK用作 “hub” 的使用场景，SDK需要提供一些必要的方法提供需要缓存（持久化）的数据操作途径，这时可以通过定义、实现 [WeChat.Adapter.Storage.Hub]() 行为，来完成相关的`access_token`持久化适配。
	* 直接对接某个微信公众号，该SDK用作 “client” 的使用场景，SDK仅需要提供一些方法从“hub”获取、清空`access_token`，这时可以通过定义、实现 [WeChat.Adapter.Storage.Client]() 行为，来完成相关的`access_token`持久化适配。

2. 使用该SDK对接某个微信第三方平台应用，通过公众号授权相关功能给这个第三方平台的应用，将通过第三方平台应用来调用已授权公众号的相关接口

	* 对接第三方平台应用，该SDK用作 “hub” 的使用场景，SDK需要提供一些必要的方法提供需要缓存（持久化）的数据操作途径，这时可以通过定义、实现 [WeChat.Adapter.Storage.ComponentHub]() 行为，来完成相关的`access_token`/`component_access_token`持久化适配。
	* 对接第三方平台应用，该SDK用作 “client” 的使用场景，SDK仅需要提供一些方法从 component application “hub” 获取、清空`access_token`/`component_access_token`，这时可以通过定义、实现 [WeChat.Adapter.Storage.ComponentClient]() 行为，来完成相关的`access_token`/`component_access_token`持久化适配。

**注意*：无论是直接对接公众号开发，还是第三方应用的集成，SDK默认是作为 “client” 的使用场景，且对 “hub” 实现一套默认Http请求操作（详情请见`WeChat.Storage.Default`）

## 如何使用

### 添加至依赖

```elixir
def deps do
  [
   {:elixir_wechat, "~> 0.1"}
  ]
end
```

### 作为 “client” 的使用场景

```elixir
# 配置config，这里的`hub_base_url`填写hub web服务的host及http协议
config :elixir_wechat,
  hub_base_url: "http://localhost:4000"
```
	
#### 直连微信公众号应用开发

```elixir
defmodule MyAppClient do
  use WeChat,
    appid: "myappid"
end
```

以上创建`MyAppClient`的方式，与下面的方式结果是一样的

```elixir
defmodule MyAppClient do
  use WeChat,
    appid: "myappid",
    adapter_storage: WeChat.Storage.Default, # by default if not set it.
    scenario: :client # by default if not set it.
end
```

如果需要替换默认的`WeChat.Storage.Default`，可以通过实现`WeChat.Adapter.Storage.Client`相关定义的module来完成。

#### 对接第三方应用的集成

```elixir
defmodule MyComponentAppClient do
  use WeChat.Component,
    appid: "mycomponentappid"
end
```

以上创建`MyComponentAppClient`的方式，与下面的方式结果是一样的

```elixir
defmodule MyComponentAppClient do
  use WeChat.Component,
    appid: "mycomponentappid",
    adapter_storage: WeChat.Storage.ComponentDefault,
    scenario: :client
end
```

如果需要替换默认的`WeChat.Storage.ComponentDefault`，可以通过实现`WeChat.Adapter.Storage.ComponentClient`相关定义的module来完成。

### 作为 “hub” 的使用场景

> 与作为 “client” 的使用场景对比，在config文件中无需做任何配置。

#### 直连微信公众号应用开发

```elixir
defmodule MyAppClient do
  use WeChat,
    appid: "myappid",
    scenario: :hub,
    adapter_storage: WeChat.Storage.MyImpl
end
```

以上示例中的`WeChat.Storage.MyImpl`，需要实现`WeChat.Adapter.Storage.Hub`行为。

#### 对接第三方应用的集成

```elixir
defmodule MyComponentAppClient do
  use WeChat.Component,
    appid: "mycomponentappid",
    scenario: :hub,
    adapter_storage: WeChat.Storage.MyImpl
end
```

> 以上各种使用场景中所创建调用微信接口的客户端，appid(公众号appid或微信第三方应用appid)，可以在构造客户端的时候填入，
> 这时构造的客户端就包含了该appid作为全局信息，在之后具体调用微信接口的时候，就可以不用再提供这个参数，这种方式通常适用于作为客户端调用，只需要维护一个appid的情况下；当需要作为服务端的调用请求，支持多个appid动态请求的情况，可以用如下的方式构造：

```elixir
#
# 以对接第三方应用的集成作为示例，其他场景下构造客户端的时候不填写appid同样适用
#
defmodule MyComponentAppClient do
  use WeChat.Component,
    scenario: :hub,
    adapter_storage: WeChat.Storage.MyImpl
end
```

以上示例中的`WeChat.Storage.MyImpl`，需要实现`WeChat.Adapter.Storage.ComponentHub`行为。


## 文档

更多详情请见文档

```bash
$ MIX_ENV=docs mix docs
```

## 需要更多的微信接口支持

随着微信平台有更多接口的开放及更新，预期中，我们可以通过调整在`config/wechat_api.toml`和`config/wechat_component_api.toml`中的配置来维护这个客户端代码库。

目前这个SDK的设计思路是把微信公开接口中那些“不太统一”的地方，全部放在以上2个toml文件中配置管理，然后通过定义好所需要使用客户端的场景，完成对缓存存储的适配，再批量生成那些需要使用的通用微信接口。

我们预设使用这个SDK的时候，依然会参考微信官方的接口文档，SDK的使用者需要准备对应接口所需的参数（除了`access_token`和`component_access_token`）及相关性校验，该SDK只负责接口的调用，具体业务参数的校验目前不在处理范围中。

生成的微信接口方法请见文档中的“MODULES - GUIDE”，或了解测试用例。

## Lincese

MIT
