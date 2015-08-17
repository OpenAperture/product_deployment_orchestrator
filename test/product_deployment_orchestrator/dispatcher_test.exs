defmodule OpenAperture.ProductDeploymentOrchestrator.DispatcherTests do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Httpc

  alias OpenAperture.ProductDeploymentOrchestrator.Dispatcher

  alias OpenAperture.Messaging.AMQP.ConnectionPool
  alias OpenAperture.Messaging.AMQP.ConnectionPools
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler
  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.ConnectionOptions, as: AMQPConnectionOptions
  alias OpenAperture.Messaging.AMQP.QueueBuilder

  alias OpenAperture.ProductDeploymentOrchestrator.MessageManager
  alias OpenAperture.ProductDeploymentOrchestrator.Configuration
  alias OpenAperture.ProductDeploymentOrchestrator.ProductDeploymentFSM

  alias OpenAperture.ManagerApi
  
  # ===================================
  # register_queues tests

  test "register_queues success" do
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, _, _, _ -> :ok end)

    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _, _ -> %AMQPConnectionOptions{} end)

    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> %OpenAperture.Messaging.Queue{name: ""} end)      

    assert Dispatcher.register_queues == :ok
  after
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
    :meck.unload(ConnectionOptionsResolver)
    :meck.unload(QueueBuilder)
  end

  test "register_queues failure" do
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, _, _, _ -> {:error, "bad news bears"} end)

    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _, _ -> %AMQPConnectionOptions{} end)    

    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> %OpenAperture.Messaging.Queue{name: ""} end)      

    assert Dispatcher.register_queues == {:error, "bad news bears"}
  after
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
    :meck.unload(ConnectionOptionsResolver)
    :meck.unload(QueueBuilder)
  end  

  # ===================================
  # execute_orchestration tests

  test "execute_orchestration - success" do
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, _, _, _ -> :ok end)

    :meck.new(ProductDeploymentFSM, [:passthrough])
    :meck.expect(ProductDeploymentFSM, :start_link, fn _, _ -> {:ok, nil} end)    
    :meck.expect(ProductDeploymentFSM, :execute, fn _ -> {:completed, %{}} end)

    payload = %{
      id: 123
    }
    Dispatcher.execute_orchestration(payload, "123abc")
  after
    :meck.unload(ProductDeploymentFSM)
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
  end

  test "execute_orchestration - failure" do
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, _, _, _ -> :ok end)

    :meck.new(ProductDeploymentFSM, [:passthrough])
    :meck.expect(ProductDeploymentFSM, :start_link, fn _, _ -> {:error, "bad news bears"} end)    
    :meck.expect(ProductDeploymentFSM, :execute, fn _ -> {:error, "bad news bears"} end)

    payload = %{
      id: 123
    }
    assert_raise RuntimeError, "Unable to process request 123abc (workflow 123):  \"bad news bears\"", fn -> Dispatcher.execute_orchestration(payload, "123abc") end
  after
    :meck.unload(ProductDeploymentFSM)
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
  end  

  test "acknowledge" do
    :meck.new(MessageManager, [:passthrough])
    :meck.expect(MessageManager, :remove, fn _ -> %{} end)

    :meck.new(SubscriptionHandler, [:passthrough])
    :meck.expect(SubscriptionHandler, :acknowledge, fn _, _ -> :ok end)

    Dispatcher.acknowledge("123abc")
  after
    :meck.unload(MessageManager)
    :meck.unload(SubscriptionHandler)
  end

  test "reject" do
    :meck.new(MessageManager, [:passthrough])
    :meck.expect(MessageManager, :remove, fn _ -> %{} end)

    :meck.new(SubscriptionHandler, [:passthrough])
    :meck.expect(SubscriptionHandler, :reject, fn _, _, _ -> :ok end)

    Dispatcher.reject("123abc")
  after
    :meck.unload(MessageManager)
    :meck.unload(SubscriptionHandler)
  end  
end