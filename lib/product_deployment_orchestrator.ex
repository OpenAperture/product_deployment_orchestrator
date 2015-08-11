defmodule OpenAperture.ProductDeploymentOrchestrator do

require Logger

  @spec start(atom, [any]) :: :ok | {:error, String.t}
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    Logger.info("Starting OpenAperture.ProductDeploymentOrchestrator.Supervisor...")
    children = [
      # Define workers and child supervisors to be supervised
      supervisor(OpenAperture.ProductDeploymentOrchestrator.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
