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
        :openaperture_overseer_api,
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
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "8c51d099ec79473b23b3c385c072e6bf2219fba7", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git", ref: "bc92a7592396bb631ea3b2ea9862fe0ac3ad39eb", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "4d65d2295f2730bc74ec695c32fa0d2478158182", override: true},

      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "2e63b7889c76f4d3b749146f3ebceb01702cf012", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "6a30773415161146aeb0e07c6b2f456d1e0d8d48", override: true},
      
      {:timex_extensions, git: "https://github.com/OpenAperture/timex_extensions.git", ref: "ab9d8820625171afbb80ccba1aa48feeb43dd790", override: true},

      {:timex, "~> 0.12.9"},
      {:fleet_api, "~> 0.0.6"},
      {:poison, "~>1.4.0", override: true},

      #test dependencies
      {:exvcr, github: "parroty/exvcr", override: true},
      {:meck, "0.8.2", override: true}
    ]
  end
end
