#
# == configuration.ex
#
# This module contains the logic to retrieve configuration from either the environment or configuration files
#
defmodule OpenAperture.ProductDeploymentOrchestrator.Configuration do

  @doc """
  Method to retrieve the currently assigned exchange id
   
  ## Options
   
  ## Return values

  The exchange identifier
  """ 
  @spec get_current_exchange_id() :: String.t
  def get_current_exchange_id do
    get_config(:openaperture_product_deployment_orchestrator, :exchange_id)
  end

  @doc """
  Method to retrieve the currently assigned exchange id
   
  ## Options
   
  ## Return values

  The exchange identifier
  """ 
  @spec get_current_broker_id() :: String.t
  def get_current_broker_id do
    get_config(:openaperture_product_deployment_orchestrator, :broker_id)
  end

  @doc """
  Method to retrieve the wait time for the fsm before checking the status of a running workflow
   
  ## Options
   
  ## Return values

  The exchange identifier
  """ 
  @spec get_workflow_checkback_time() :: String.t
  def get_workflow_checkback_time do
    get_config(:openaperture_product_deployment_orchestrator, :workflow_checkback_time)
  end

  @doc """
  Method to retrieve the currently assigned queue name (for "workflow_orchestration")
   
  ## Options
   
  ## Return values

  The exchange identifier
  """ 
  @spec get_current_queue_name() :: String.t
  def get_current_queue_name do
    System.get_env("QUEUE_NAME") || get_config(:openaperture_overseer, :queue_name)
  end

  @doc false
  # Method to retrieve a configuration option from the environment or config settings
  # 
  ## Options
  # 
  # The `env_name` option defines the environment variable name
  #
  # The `application_config` option defines the config application name (atom)
  #
  # The `config_name` option defines the config variable name (atom)
  # 
  ## Return values
  # 
  # Value
  # 
  @spec get_config(atom, atom) :: String.t
  defp get_config(application_config, config_name) do
    Application.get_env(application_config, config_name)
  end  
end