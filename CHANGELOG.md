# Changelog

## v0.4.4 (2021-06-02)

* Fix warning internally used tesla/httpc when ssl connect to self-hub

## v0.4.3 (2021-05-27)

* Fix authorizer_appid was mistaken for component appid when set appid param in query string
* Fix no function clause matching when access_token is invalid in some case

## v0.4.2 (2021-03-03)

* Fix input invalid `access_token` when call sns userinfo and auth API made infinity retry

## v0.4.1 (2021-02-08)

* Fix some cases fail to get component `access_token` from hub [#8](https://github.com/edragonconnect/elixir_wechat/pull/8)

## v0.4.0 (2021-01-15)

* Fix Elixir 1.11 compilation warnings

## v0.3.1 (2020-12-16)

* Fix WeChat.Registry to use :ets as a global storage instead of Elixir Registry

## v0.3.0 (2020-12-16)

* Add local registry for `access_token` and `ticket` in client to effectively call WeChat functional API
* Use `Tesla.Middleware.Retry` for http socket closed/timeout
* Use `Tesla.Adapter.Finch` to process http request/response
* Fix http middleware rerun was using unexpected `Tesla.Env`
* Fix adapter storage validation in WeChat common application
* Change the reason field of `WeChat.Error` struct from atom to string
