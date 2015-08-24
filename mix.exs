defmodule ProductDeploymentOrchestrator.Mixfile do
  use Mix.Project

  def project do
    [app: :product_deployment_orchestrator,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  def application do
    [
      mod: { OpenAperture.ProductDeploymentOrchestrator, [] },
      applications: [
        :logger, 
        :openaperture_messaging, 
        :openaperture_manager_api,
        :openaperture_product_deployment_orchestrator_api
        #:openaperture_overseer_api
      ]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:ex_doc, "0.7.3", only: :test},
      {:earmark, "0.1.17", only: :test},
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "3d3a84eabf4ba0a3a827a61c4d99cdbf0ab49a0d", override: true},
      #{:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git", ref: "8f22b612ed97360436008296ecaf8945363d8763", override: true},
      {:openaperture_manager_api, path: "../manager_api", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "4b9146507ab50789fec4696b96f79642add2b502", override: true},

      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "714c52b5258f96e741b57c73577431caa6f480b3", override: true},
      #{:openaperture_product_deployment_orchestrator_api, git: "https://github.com/OpenAperture/product_deployment_orchestrator_api.git", ref: "466c1d8b5e73bc7d20316298d716d88c17162f53", override: true},
      {:openaperture_product_deployment_orchestrator_api, path: "../product_deployment_orchestrator_api", override: true},

      {:timex_extensions, git: "https://github.com/OpenAperture/timex_extensions.git", ref: "1665c1df90397702daf492c6f940e644085016cd", override: true},

      {:timex, "~> 0.12.9"},
      {:fleet_api, "~> 0.0.14"},
      {:poison, "~>1.4.0", override: true},

      #test dependencies
      {:exvcr, github: "parroty/exvcr", override: true},
      {:meck, "0.8.2", override: true}
    ]
  end
end
