defmodule GenesisPubSub.Adapter.Google.Mock do
  @moduledoc """
  A mock google adapter that keeps same contract without making any external
  calls. This module pairs well with Mox to assert how the adapter was called.

  > The only change in contract is the choice of ids. Google seems to pick a
  sequential id. To help make events unique this module substitutes uuids.

      Mox.defmock(MockAdapter, for: GenesisPubSub.Adapter)

      Mox.expect(MockAdapter, :publish, fn producer, message ->
        # do any assertions needed
        # ...snip...
        # use google mock to keep same contract
        GenesisPubSub.Adapter.Google.Mock.publish(topic, message)
      end)

      {:ok, published_message} = GenesisPubSub.Producer.publish(MyProducer, message)

  See Testing Guide for more explanation on testing producers and consumers.
  """
  alias GenesisPubSub.Adapter.Google
  alias GenesisPubSub.Message
  @behaviour GenesisPubSub.Adapter

  @impl GenesisPubSub.Adapter
  def publish(topic, %Message{} = message) do
    publish_start = GenesisPubSub.Telemetry.publish_start(topic, [message])
    published_message = Google.set_published_meta(message, UUID.uuid4())
    GenesisPubSub.Telemetry.publish_end(publish_start, topic, [published_message])
    {:ok, published_message}
  end

  @impl GenesisPubSub.Adapter
  def publish(topic, [%Message{} | _others] = messages) do
    publish_start = GenesisPubSub.Telemetry.publish_start(topic, messages)
    ids = 1..Enum.count(messages)

    messages =
      Enum.zip(messages, ids)
      |> Enum.map(fn {message, published_message_id} ->
        Google.set_published_meta(message, published_message_id)
      end)

    GenesisPubSub.Telemetry.publish_end(publish_start, topic, messages)

    {:ok, messages}
  end

  @impl GenesisPubSub.Adapter
  defdelegate unpack(message), to: Google

  @impl GenesisPubSub.Adapter
  defdelegate test_message(module, message), to: Google
end
