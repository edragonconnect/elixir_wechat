defmodule TestComponentClient1 do
  use WeChat.Component, appid: "wxfb5c222213d161f2"
end

defmodule TestComponentClient2 do
  use WeChat.Component,
    appid: "wxfb5c222213d161f2",
    authorizer_appid: "wx6973a7470c360256"
end
