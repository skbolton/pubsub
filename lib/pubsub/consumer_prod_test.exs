defmodule GenesisPubSub.ConsumerProdTest do
  # Need async: false here because we're changing an environment wide 
  # configuration value that would interfere with other test files
  use ExUnit.Case, async: false
  import Hammox
  alias GenesisPubSub.TestGenesisConsumer

  setup :verify_on_exit!

  setup do
    # turn off test mode to test the prod options
    Application.put_env(:genesis_pubsub, :test_mode?, false)

    MockAdapter
    |> stub(:broadway_producer, fn _opts -> [module: {Broadway.DummyProducer, []}] end)

    on_exit(fn -> Application.put_env(:genesis_pubsub, :test_mode?, true) end)
  end

  test "can set processor concurrency in production" do
    assert {:ok, _pid} = TestGenesisConsumer.start_link()
    processors = Supervisor.which_children(GenesisPubSub.TestGenesisConsumer.Broadway.ProcessorSupervisor)

    # ensure the ProcessorSupervisor's children are the processes we expect
    assert Enum.all?(processors, &({_ref, _child_pid, :worker, [Broadway.Topology.ProcessorStage]} = &1))
    # ensure we have the prod default # of processors running
    assert System.schedulers_online() * 2 == length(processors)
    assert Supervisor.stop(TestGenesisConsumer)

    # now start the consumer with a custom processor concurrency value
    concurrent_processors = 4
    assert {:ok, _pid} = TestGenesisConsumer.start_link(processors: [default: [concurrency: concurrent_processors]])

    processors = Supervisor.which_children(GenesisPubSub.TestGenesisConsumer.Broadway.ProcessorSupervisor)

    # ensure the ProcessorSupervisor's children are the processes we expect
    assert Enum.all?(processors, &({_ref, _child_pid, :worker, [Broadway.Topology.ProcessorStage]} = &1))
    # ensure we have the specified # of processors running
    assert concurrent_processors == length(processors)
    assert Supervisor.stop(TestGenesisConsumer)
  end
end
