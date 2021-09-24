defmodule GenesisPubSub.Adapter.NoOp do
  @moduledoc """
  A no-op adapter that raises if you try to use it. Useful for local development
  when you don't need to work with pubsub as you don't need to start the
  pubsub emulator.
  """
  @behaviour GenesisPubSub.Adapter

  alias GenesisPubSub.Adapter.Google

  require Logger

  @impl GenesisPubSub.Adapter
  def publish(topic, message) do
    Logger.error(
      "You are using the NoOp client and publish is being mocked. Change your config to use the GoogleLocal client if you want to test with the pubsub emulator."
    )

    Google.Mock.publish(topic, message)
  end

  @impl GenesisPubSub.Adapter
  defdelegate unpack(message), to: Google

  @impl GenesisPubSub.Adapter
  defdelegate unpack_metadata(message), to: Google

  @impl GenesisPubSub.Adapter
  defdelegate pack(acknowledger, batch_mode, message), to: Google

  @impl GenesisPubSub.Adapter
  def broadway_producer(_opts) do
    [module: {Broadway.DummyProducer, []}]
  end
end
