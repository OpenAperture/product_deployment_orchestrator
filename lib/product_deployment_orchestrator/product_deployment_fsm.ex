#
# == workflow_fsm.ex
#
# This module contains the gen_fsm for ProductDeployment Orchestration.  Most executions 
# through this FSM will follow one of the following path(s):
#
#   * Deployment in progress, current step is build_deploy, build_deploy hasn't started
#     :determine_next_step
#     :build_deploy
#     :build_deploy
#     :awaiting_build_deploy
#   * Deployment in progress, current step is build_deploy, build_deploy hasn't finished
#     :determine_next_step
#     :build_deploy
#     :awaiting_build_deploy
#   * Deployment in progress, current step is build_deploy, build_deploy has finished
#     :determine_next_step
#     :build_deploy
#     :deployment_step_completed
#   * Deployment is complete
#     :determine_next_step
#     :deployment_completed
#
require Logger
require Timex.Date

defmodule OpenAperture.ProductDeploymentOrchestrator.ProductDeploymentFSM do

  @moduledoc """
  This module contains the gen_fsm for ProductDeployment Orchestration
  """

  use Timex

  @behaviour :gen_fsm

  alias OpenAperture.ProductDeploymentOrchestrator.Configuration

  alias OpenAperture.ProductDeploymentOrchestratorApi.Request, as: OrchestratorRequest
  alias OpenAperture.ProductDeploymentOrchestratorApi.ProductDeploymentOrchestrator.Publisher, as: OrchestratorPublisher
  alias OpenAperture.ProductDeploymentOrchestratorApi.Deployment
  alias OpenAperture.ProductDeploymentOrchestratorApi.DeploymentStep
  alias OpenAperture.ProductDeploymentOrchestratorApi.PlanTreeNode

  alias OpenAperture.ManagerApi.Workflow, as: WorkflowApi
  alias OpenAperture.ManagerApi.ProductDeploymentStep, as: ProductDeploymentStepApi
  alias OpenAperture.ManagerApi

  

  @doc """
  Method to start a ProductDeployment Orchestration

  ## Options

  The `payload` options defines the payload of the Workflow

  The `delivery_tag` options defines the identifier of the request message to which this FSM is associated

  ## Return Values
  
  {:ok, ProductDeploymentFSM} | {:error, reason}
  """
  @spec start_link(map, String.t) :: {:ok, pid} | {:error, String.t}
  def start_link(payload, delivery_tag) do
    Logger.debug("Start Link called")

    request = OrchestratorRequest.from_payload(payload)
    %{
      step_info: request.step_info, 
      deployment: request.deployment,
      deployment_step: request.deployment_step,
      delivery_tag: delivery_tag,
      product_deployment_orchestration_queue: request.product_deployment_orchestration_queue,
      product_deployment_orchestration_exchange_id: request.product_deployment_orchestration_exchange_id,
      product_deployment_orchestration_broker_id: request.product_deployment_orchestration_broker_id,
      completed: request.completed,
      product_deployment_orchestration_prefix: "[ProductDeploymentFSM][#{UUID.uuid1()}]"
    }
    |> __MODULE__.start_link_with_args()
  end

  @spec start_link_with_args(map) :: {:ok, pid} | {:error, String.t}
  def start_link_with_args(args) do
    :gen_fsm.start_link(__MODULE__, args, [])
  end

  @spec init(term) :: {:ok, :determine_next_step, term}
  def init(state_data) do
    {:ok, :determine_next_step, state_data}
  end

  @spec handle_info(term, atom, term) :: {:next_state, atom, term}
  def handle_info(_info, current_state, state_data) do
    {:next_state,current_state,state_data}
  end   

  @spec handle_event(term, atom, term) :: {:next_state, atom, term}
  def handle_event(_event, current_state, state_data) do
    Logger.debug("Proceeding to state: #{current_state}")
    {:next_state,current_state,state_data}
  end   

  @spec handle_sync_event(term, term, atom, term) :: {:next_state, atom, term}
  def handle_sync_event(_event, _from, current_state, state_data) do
    Logger.debug("Proceeding to state: #{current_state}")
    {:next_state, current_state, state_data}
  end 

  @spec code_change(term, atom, term, term) :: {:ok, atom, term}
  def code_change(_old_vsn, current_state, state_data, _opts) do
    {:ok, current_state, state_data}
  end

  @spec execute(pid) :: {:completed, nil | Deployment.t}
  def execute(fsm) do
    case :gen_fsm.sync_send_event(fsm, :execute_next_deployment_step, 15000) do
      :in_progress -> 
        execute(fsm)
      {:awaiting_build_deploy, request} ->
        OrchestratorPublisher.execute_orchestration(request)
        {:completed, nil}
      {:completed, workflow} -> 
        {:completed, workflow}
    end
  end

  @spec determine_next_step(term, term, term) :: {:reply, :in_progress, :build_deploy | :deployment_completed, term} | {:stop, :normal, {:error, String.t}, term}
  def determine_next_step(_event, _from, state_data) do
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} determining next step")
    #Setup logging
    state_data = Map.update!(state_data, :deployment, &(%{&1 | output: []}) )

    current_step = Deployment.determine_current_step(state_data[:deployment].plan_tree)
    state_data = Map.put(state_data, :current_step, current_step)

    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Found step: #{inspect(current_step)}")

    case current_step do 
      nil -> 
        Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} step is nil")
        {:reply, :in_progress, :deployment_completed, state_data}
      step ->
        Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} step is NOT nil")
        {:reply, :in_progress, String.to_atom(step.type), state_data}
    end
  end

  @spec build_deploy(term, term, term) :: {:reply, :in_progress, :build_deploy | :build_deploy_in_progress | :deployment_step_completed, term}
  def build_deploy(_current_state, _from, %{current_step: current_step = %PlanTreeNode{status: nil}} = state_data) do
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Creating new workflow!")

    #Log step start to manager
    state_data = Map.update!(state_data, :deployment_step, fn _ -> __MODULE__.create_deployment_step(state_data, current_step).body |> DeploymentStep.from_response_body(state_data[:deployment].product_name) end)
    
    options = Map.merge(current_step.options, current_step.execution_options)

    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Creating workflow with these options: #{inspect options}")

    case WorkflowApi.create_workflow!(ManagerApi.get_api, options, %{}, [], []) do 
      nil -> 
        Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Failed to create workflow")
        state_data = Map.update!(state_data, :deployment, &( %{&1 | plan_tree: Deployment.update_current_step_status(&1.plan_tree, "failure")} ))
        state_data = append_output_log(state_data, :deployment, "Failed to create workflow! Options: #{Poison.encode!(inspect options)}")
        {:reply, :in_progress, :deployment_step_completed, state_data}
      workflow_id -> 
        state_data = Map.update!(state_data, :deployment, &( %{&1 | plan_tree: Deployment.update_current_step_status(&1.plan_tree, "in_progress")} ))
        state_data = append_output_log(state_data, :deployment, "Successfully created workflow #{workflow_id}")
        state_data = Map.update!(state_data, :step_info, &( Map.put(&1, :workflow_id, workflow_id) ))
        state_data = Map.update!(state_data, :deployment, &Deployment.save/1)
        {:reply, :in_progress, :build_deploy, state_data}
      
    end 
  end

  def build_deploy(_current_state, _from, %{current_step: %PlanTreeNode{status: "in_progress"}} = state_data) do
    :timer.sleep(Configuration.get_workflow_checkback_time)
    workflow = WorkflowApi.get_workflow(ManagerApi.get_api(), state_data[:step_info][:workflow_id]).body
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]}  Current workflow: #{inspect workflow}")
    status = cond do
      workflow["workflow_error"] -> "failure"
      workflow["workflow_completed"] -> "success"
      true -> "in_progress"
    end
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]}  Status of workflow determined to be: #{status}")

    state_data = Map.update!(state_data, :deployment, &( %{&1 | plan_tree: Deployment.update_current_step_status(&1.plan_tree, status)} ))

    case status do 
      "in_progress" ->
        state_data = append_output_log(state_data, :deployment_step, "Awaiting completion of build_deploy workflow: #{state_data[:step_info][:workflow_id]}")
        {:reply, :in_progress, :build_deploy_in_progress, state_data}
      completion_status -> 
        Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Workflow completed. Completion status: #{completion_status}")
        state_data = append_output_log(state_data, :deployment_step, "Workflow: #{state_data[:step_info][:workflow_id]} has finished in #{completion_status}!")
        state_data = Map.update!(state_data, :deployment_step, &( %{&1 | successful: completion_status == "success"} ))
        state_data = append_output_log(state_data, :deployment, "Deployment Step: #{state_data[:deployment_step].id} has completed")
        {:reply, :in_progress, :deployment_step_completed, state_data}
    end
  end

  @spec build_deploy_in_progress(term, term, term) :: {:stop, :normal, {:awaiting_build_deploy, term}, term}
  def build_deploy_in_progress(_reason, _current_state, state_data) do 
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Awaiting completion of workflow.") 
    state_data = Map.update!(state_data, :deployment_step, &DeploymentStep.save/1)
    state_data = Map.update!(state_data, :deployment, &Deployment.save/1)
    {:stop, :normal, {:awaiting_build_deploy, state_data}, state_data}
  end

  @spec deployment_step_completed(term, term, term) :: {:stop, :normal, {:completed, term}, term}
  def deployment_step_completed(_reason, _current_state, state_data) do
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Deployment step completed.") 
    state_data = Map.update!(state_data, :deployment_step, &DeploymentStep.save/1) 
    state_data = Map.update!(state_data, :deployment, &Deployment.save/1)
    OrchestratorPublisher.execute_orchestration(state_data)
    {:stop, :normal, {:completed, state_data}, state_data}
  end 

  @spec deployment_completed(term, term, term) :: {:stop, :normal, {:completed, term}, term}
  def deployment_completed(_reason, _current_state, state_data) do 
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Deployment completed.") 
    state_data = Map.update!(state_data, :deployment, &(%{&1 | completed: true}) )
    state_data = append_output_log(state_data, :deployment, "Deployment has completed!")
    state_data = Map.update!(state_data, :deployment, &Deployment.save/1)
    {:stop, :normal, {:completed, state_data}, state_data}
  end

  def append_output_log(state_data, model, log) do 
    Map.update!(state_data, model, &( %{&1 | output: &1.output ++ [log]} ))
  end 

  def create_deployment_step(state_data, current_step) do 
    #Log step start to manager
    new_step_id = ProductDeploymentStepApi.create_step!(ManagerApi.get_api, state_data[:deployment].product_name, state_data[:deployment].deployment_id, %{
      product_deployment_plan_step_id: current_step.id,
      product_deployment_plan_step_type: current_step.type,
      duration: "1",
      output: Poison.encode!(["#{current_step.type} has begun"]),
      successful: nil
    })

    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Product deployment step created.") 

    ProductDeploymentStepApi.get_step(ManagerApi.get_api, state_data[:deployment].product_name, state_data[:deployment].deployment_id, new_step_id)
  end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:terminate-3

  ## Options

  The `reason` option defines the termination reason (:shutdown, :normal)

  The `current_state` option contains the last state of the :gen_fsm server

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  :ok
  """
  @spec terminate(term, term, term) :: :ok
  def terminate(_reason, _current_state, state_data) do
    Logger.debug("#{state_data[:product_deployment_orchestration_prefix]} Deployment orchestration has finished normally") 
    :ok
  end
end