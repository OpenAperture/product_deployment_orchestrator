require Logger

defmodule OpenAperture.ProductDeploymentOrchestrator.Dispatcher do
  use GenServer

  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler

  alias OpenAperture.ProductDeploymentOrchestrator.MessageManager
  alias OpenAperture.ProductDeploymentOrchestrator.Configuration
  alias OpenAperture.ProductDeploymentOrchestrator.ProductDeploymentFSM

  alias OpenAperture.ManagerApi
  alias OpenAperture.ManagerApi.SystemEvent

  @moduledoc """
  This module contains the logic to dispatch WorkflowOrchestrator messsages to the appropriate GenServer(s) 
  """  

  @connection_options nil
  use OpenAperture.Messaging

  @doc """
  Specific start_link implementation (required by the supervisor)
  ## Options
  ## Return Values
  {:ok, pid} | {:error, reason}
  """
  @spec start_link() :: {:ok, pid} | {:error, String.t}   
  def start_link do
    case GenServer.start_link(__MODULE__, %{}, name: __MODULE__) do
      {:error, reason} -> 
        IO.puts("An error occurred: #{inspect reason}")
        Logger.error("Failed to start OpenAperture ProductDeploymentOrchestrator:  #{inspect reason}")
        {:error, reason}
      {:ok, pid} ->
        try do
          if Application.get_env(:autostart, :register_queues, false) do
            case register_queues do
              {:ok, _} -> {:ok, pid}
              {:error, reason} -> 
                Logger.error("Failed to register ProductDeploymentOrchestrator queues:  #{inspect reason}")
                {:ok, pid}
            end       
          else
            {:ok, pid}
          end
        rescue e in _ ->
          IO.puts("An error occurred: #{inspect e}")
          Logger.error("An error occurred registering ProductDeploymentOrchestrator queues:  #{inspect e}")
          {:ok, pid}
        end
    end
  end

  @doc """
  Method to register the WorkflowOrchestrator queues with the Messaging system
  ## Return Value
  :ok | {:error, reason}
  """
  @spec register_queues() :: :ok | {:error, String.t}
  def register_queues do
    Logger.debug("Registering ProductDeploymentOrchestrator queues...")
    product_deployment_orchestrator_queue = QueueBuilder.build(ManagerApi.get_api, Configuration.get_current_queue_name, Configuration.get_current_exchange_id)

    options = OpenAperture.Messaging.ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, Configuration.get_current_broker_id)
    subscribe(options, product_deployment_orchestrator_queue, fn(payload, _meta, %{delivery_tag: delivery_tag} = async_info) -> 
      try do
        MessageManager.track(async_info)
        execute_orchestration(payload, delivery_tag) 
        acknowledge(delivery_tag)
      catch
        :exit, code   -> 
          msg = "Message #{delivery_tag} (workflow #{payload[:id]}) Exited with code #{inspect code}.  Payload:  #{inspect payload}"
          log_system_event(:unhandled_exception, msg, payload)
          Logger.error(msg)
          acknowledge(delivery_tag)
        :throw, value -> 
          msg = "Message #{delivery_tag} (workflow #{payload[:id]}) Caught thrown error with #{inspect value}.  Payload:  #{inspect payload}"
          log_system_event(:unhandled_exception, msg, payload)
          Logger.error(msg)
          acknowledge(delivery_tag)
        what, value   ->
          msg = "Message #{delivery_tag} (workflow #{payload[:id]}) Caught #{inspect what} with #{inspect value}.  Payload:  #{inspect payload}"
          log_system_event(:unhandled_exception, msg, payload)
          Logger.error(msg)
          acknowledge(delivery_tag)
      end
    end)
  end

  @doc """
  Method to start Workflow Orchestrations
  ## Options
  The `payload` option is the Map of HipChat options
  The `delivery_tag` option is the unique identifier of the message
  """
  @spec execute_orchestration(map, String.t) :: term
  def execute_orchestration(payload, delivery_tag) do
    case ProductDeploymentFSM.start_link(payload, delivery_tag) do
      {:ok, pdfsm} ->
        {:completed, _} = ProductDeploymentFSM.execute(pdfsm)
        Logger.debug("Successfully completed pass of FSM with message #{delivery_tag}")
      {:error, reason} -> 
        #raise an exception to kick the to another orchestrator (hopefully that can process it)
        raise "Unable to process request #{delivery_tag} (workflow #{payload[:id]}):  #{inspect reason}"
    end
  end

  def log_system_event(type, msg, data) do 
    event = %{
      unique: true,
      type: type,
      severity: :error,
      data: data,
      message: msg
    }
    SystemEvent.create_system_event!(ManagerApi.get_api, event)
  end 

  @doc """
  Method to acknowledge a message has been processed
  ## Options
  The `delivery_tag` option is the unique identifier of the message
  """
  @spec acknowledge(String.t) :: term
  def acknowledge(delivery_tag) do
    message = MessageManager.remove(delivery_tag)
    unless message == nil do
      SubscriptionHandler.acknowledge(message[:subscription_handler], message[:delivery_tag])
    end
  end

  @doc """
  Method to reject a message has been processed
  ## Options
  The `delivery_tag` option is the unique identifier of the message
  The `redeliver` option can be used to requeue a message
  """
  @spec reject(String.t, term) :: term
  def reject(delivery_tag, redeliver \\ false) do
    message = MessageManager.remove(delivery_tag)
    unless message == nil do
      SubscriptionHandler.reject(message[:subscription_handler], message[:delivery_tag], redeliver)
    end
  end  
end