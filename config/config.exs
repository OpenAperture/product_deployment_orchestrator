# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#

config :autostart,
  register_queues: true

config :openaperture_overseer_api,
  module_type: :product_deployment_orchestrator,
  exchange_id: System.get_env("EXCHANGE_ID"),
  broker_id: System.get_env("BROKER_ID")

config :openaperture_manager_api, 
  manager_url: System.get_env("MANAGER_URL"),
  oauth_login_url: System.get_env("OAUTH_LOGIN_URL"),
  oauth_client_id: System.get_env("OAUTH_CLIENT_ID"),
  oauth_client_secret: System.get_env("OAUTH_CLIENT_SECRET")

config :openaperture_product_deployment_orchestrator,
  exchange_id: System.get_env("EXCHANGE_ID"),
  broker_id: System.get_env("BROKER_ID")

import_config "#{Mix.env}.exs"
