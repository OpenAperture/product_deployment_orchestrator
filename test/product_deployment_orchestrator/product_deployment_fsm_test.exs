defmodule OpenAperture.ProductDeploymentOrchestrator.ProductDeploymentFSMTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Httpc, options: [clear_mock: true]

  alias OpenAperture.ProductDeploymentOrchestrator.ProductDeploymentFSM

  alias OpenAperture.ProductDeploymentOrchestratorApi.Deployment
  alias OpenAperture.ManagerApi.Workflow, as: WorkflowApi
  alias OpenAperture.ManagerApi.Deployment, as: DeploymentApi
  alias OpenAperture.ManagerApi
  alias OpenAperture.ManagerApi.Response

  alias OpenAperture.ProductDeploymentOrchestratorApi.Request, as: OrchestratorRequest
  alias OpenAperture.ProductDeploymentOrchestratorApi.ProductDeploymentOrchestrator.Publisher, as: OrchestratorPublisher
  alias OpenAperture.ProductDeploymentOrchestratorApi.PlanTreeNode

  # setup_all do
  # end

  # setup do
  # end

  # ============================
  # start_link tests

  test "start_link - success" do
    :meck.new(OrchestratorRequest, [:passthrough])
    :meck.expect(OrchestratorRequest, :from_payload, fn _ -> %OrchestratorRequest{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "build_deploy",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        completed: false,
      },
      step_info: %{}
    } end)
    
    payload = %{
    }

    {result, fsm} = ProductDeploymentFSM.start_link(payload, "#{UUID.uuid1()}")
    assert result == :ok
    assert fsm != nil
  after
    :meck.unload
  end

  test "start_link - failure" do
    :meck.new(OrchestratorRequest, [:passthrough])
    :meck.expect(OrchestratorRequest, :from_payload, fn _ -> %OrchestratorRequest{} end)
    :meck.new(:gen_fsm, [:unstick, :passthrough])
    :meck.expect(:gen_fsm, :start_link, fn _,_,_ -> {:error, "bad news bears"} end)

    {result, reason} = ProductDeploymentFSM.start_link(%{}, "#{UUID.uuid1()}")
    assert result == :error
    assert reason == "bad news bears"
  after
    :meck.unload
  end

  # ============================
  # determine_next_step tests

  test "determine_next_step - no step in progress : current_step is build_deploy" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: 1,
        on_success_step: %PlanTreeNode{
          type: "build_deploy",
          options: %{},
          execution_options: %{},
          on_success_step_id: nil,
          on_success_step: nil,
          on_failure_step_id: nil,
          on_failure_step: nil,
          status: nil
        },
        on_failure_step_id: 2,
        on_failure_step: %PlanTreeNode{
          type: "build_deploy",
          options: %{},
          execution_options: %{},
          on_success_step_id: nil,
          on_success_step: nil,
          on_failure_step_id: nil,
          on_failure_step: nil,
          status: nil
        },
        status: nil
      } end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "build_deploy",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        output: nil,
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.determine_next_step(nil, nil, state_data)
    assert action == :reply
    assert type == :in_progress
    assert response_data == :build_deploy
    assert state[:deployment].output == []
  after
    :meck.unload
  end

  test "determine_next_step - no step in progress : deployment finished" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> nil end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "build_deploy",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: "success"
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: "success"
        },
        output: nil,
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.determine_next_step(nil, nil, state_data)
    assert action == :reply
    assert type == :in_progress
    assert response_data == :deployment_completed
    assert state[:deployment].output == []
  after
    :meck.unload
  end

   test "determine_next_step -  error : step type does not match a machine state" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> %PlanTreeNode{
      type: "warblegarble",
      options: %{},
      execution_options: %{},
      on_success_step_id: 1,
      on_success_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      on_failure_step_id: 2,
      on_failure_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      status: nil
    } end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "warblegarble",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        output: nil,
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.determine_next_step(nil, nil, state_data)
    assert action == :stop
    assert type == :normal
    assert response_data == {:error, "No action match for warblegarble"}
    assert state[:deployment].output == []
  after
    :meck.unload
  end

  # ============================
  # build_deploy tests

  test "build_deploy -  in_progress : build_deploy still in progress" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> %PlanTreeNode{
      type: "build_deploy",
      options: %{},
      execution_options: %{},
      on_success_step_id: 1,
      on_success_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      on_failure_step_id: 2,
      on_failure_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      status: "in_progress"
    } end)

    :meck.expect(Deployment, :update_current_step_status, fn _, _ -> nil end)

    :meck.new(WorkflowApi, [:passthrough])
    :meck.expect(WorkflowApi, :get_workflow, fn _, _ -> %Response{body: %{}} end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "warblegarble",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        output: nil,
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.build_deploy(nil, nil, state_data)
    assert action == :reply
    assert type == :in_progress
    assert response_data == :build_deploy_in_progress
  after
    :meck.unload
  end

  test "build_deploy - in_progress : build_deploy succeeded" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> %PlanTreeNode{
      type: "build_deploy",
      options: %{},
      execution_options: %{},
      on_success_step_id: 1,
      on_success_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      on_failure_step_id: 2,
      on_failure_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      status: "in_progress"
    } end)

    :meck.expect(Deployment, :update_current_step_status, fn _, _ -> nil end)

    :meck.new(WorkflowApi, [:passthrough])
    :meck.expect(WorkflowApi, :get_workflow, fn _, _ -> %Response{body: %{workflow_completed: true}} end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "warblegarble",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        output: nil,
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.build_deploy(nil, nil, state_data)
    assert action == :reply
    assert type == :in_progress
    assert response_data == :deployment_step_completed
  after
    :meck.unload
  end

  test "build_deploy - in_progress : build_deploy failed" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> %PlanTreeNode{
      type: "build_deploy",
      options: %{},
      execution_options: %{},
      on_success_step_id: 1,
      on_success_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      on_failure_step_id: 2,
      on_failure_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      status: "in_progress"
    } end)

    :meck.expect(Deployment, :update_current_step_status, fn _, _ -> nil end)

    :meck.new(WorkflowApi)
    :meck.expect(WorkflowApi, :get_workflow, fn _, _ -> %Response{body: %{workflow_error: true}} end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "warblegarble",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        output: nil,
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.build_deploy(nil, nil, state_data)
    assert action == :reply
    assert type == :in_progress
    assert response_data == :deployment_step_completed
  after
    :meck.unload
  end

  test "build_deploy - step not started : successful workflow call" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> %PlanTreeNode{
      type: "build_deploy",
      options: %{},
      execution_options: %{},
      on_success_step_id: 1,
      on_success_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      on_failure_step_id: 2,
      on_failure_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      status: nil
    } end)

    :meck.expect(Deployment, :update_current_step_status, fn _, _ -> nil end)

    :meck.expect(Deployment, :save, fn _ -> nil end)

    :meck.new(WorkflowApi, [])
    :meck.expect(WorkflowApi, :create_workflow, fn _, _, _, _, _ -> %Response{
      status: 201,
      headers: [{"location", "something/something/1"}]
    } end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "build_deploy",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        output: [],
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.build_deploy(nil, nil, state_data)
    assert action == :reply
    assert type == :in_progress
    assert response_data == :build_deploy
    assert state[:step_info][:workflow_id] =="1"
    assert state[:deployment].output != []
  after
    :meck.unload
  end

  test "build_deploy - step not started : failed workflow call" do 
    :meck.new(Deployment, [:passthrough])
    :meck.expect(Deployment, :determine_current_step, fn _ -> %PlanTreeNode{
      type: "build_deploy",
      options: %{},
      execution_options: %{},
      on_success_step_id: 1,
      on_success_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      on_failure_step_id: 2,
      on_failure_step: %PlanTreeNode{
        type: "build_deploy",
        options: %{},
        execution_options: %{},
        on_success_step_id: nil,
        on_success_step: nil,
        on_failure_step_id: nil,
        on_failure_step: nil,
        status: nil
      },
      status: nil
    } end)

    :meck.expect(Deployment, :update_current_step_status, fn _, _ -> nil end)

    :meck.expect(Deployment, :save, fn _ -> nil end)

    :meck.new(WorkflowApi, [])
    :meck.expect(WorkflowApi, :create_workflow, fn _, _, _, _, _ -> %Response{
      status: 500,
    } end)

    state_data = %{
      product_deployment_orchestration_exchange_id: 1,
      product_deployment_orchestration_broker_id: 1,
      product_deployment_orchestration_queue: "product_deployment_orchestrator",
      deployment: %Deployment{
        product_name: "product1",
        deployment_id: 101,
        plan_tree: %PlanTreeNode{
          type: "build_deploy",
          options: %{},
          execution_options: %{},
          on_success_step_id: 1,
          on_success_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          on_failure_step_id: 2,
          on_failure_step: %PlanTreeNode{
            type: "build_deploy",
            options: %{},
            execution_options: %{},
            on_success_step_id: nil,
            on_success_step: nil,
            on_failure_step_id: nil,
            on_failure_step: nil,
            status: nil
          },
          status: nil
        },
        output: [],
        completed: false,
      },
      step_info: %{}
    }

    {action, type, response_data, state} = ProductDeploymentFSM.build_deploy(nil, nil, state_data)
    assert action == :reply
    assert type == :in_progress
    assert response_data == :build_deploy
    assert state[:step_info][:workflow_id] == nil
    assert state[:deployment].output != []
  after
    :meck.unload
  end
end
