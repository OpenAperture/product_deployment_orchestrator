defmodule OpenAperture.ProductDeploymentOrchestrator.ProductDeploymentState do 

  alias OpenAperture.ProductDeploymentOrchestratorApi.PlanTreeNode
  alias OpenAperture.ProductDeploymentOrchestratorApi.Request

  def create_from_payload(payload) do

    #Plan tree must exist, there is no suitable default
    defaults = %{
      request: %Request{},
      step_info: %{},
      delivery_tag: nil
    }

    #the payload may override the defaults back to nil
    deployment_info = Map.merge(defaults, payload)

    if deployment_info[:options] == nil do
      deployment_info = Map.put(deployment_info, :options, {})
    end

    if deployment_info[:execution_options] == nil do
      deployment_info = Map.put(deployment_info, :execution_options, [])
    end

    if deployment_info[:output] == nil do 
      deployment_info = Map.put(deployment_info, :output, [])
    end

    case Agent.start_link(fn -> deployment_info end) do
      {:ok, pid} -> pid
      {:error, reason} -> {:error, "Failed to create Deployment Agent:  #{inspect reason}"}
    end 
  end
end