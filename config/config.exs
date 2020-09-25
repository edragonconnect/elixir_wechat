# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, level: :info

if Mix.env() == :test do
  import_config "test.exs"
end
