# Changelog

## v0.3.0 (2020-12-16)

* Add local registry for `access_token` and `ticket` in client to effectively call WeChat functional API
* Use `Tesla.Middleware.Retry` for http socket closed/timeout
* Use `Tesla.Adapter.Finch` to process http request/response
* Fix http middleware rerun was using unexpected `Tesla.Env`
* Fix adapter storage validation in WeChat common application
* Change the reason field of `WeChat.Error` struct from atom to string
