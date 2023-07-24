defmodule PubSub.Adapter.Google.Mock do
  @moduledoc """
  A mock google adapter that keeps same contract without making any external
  calls. This module pairs well with Mox to assert how the adapter was called.

  > The only change in contract is the choice of ids. Google seems to pick a
  sequential id. To help make events unique this module substitutes uuids.

      Mox.defmock(MockAdapter, for: PubSub.Adapter)

      Mox.expect(MockAdapter, :publish, fn producer, message ->
        # do any assertions needed
        # ...snip...
        # use google mock to keep same contract
        PubSub.Adapter.Google.Mock.publish(topic, message)
      end)

      {:ok, published_message} = PubSub.Producer.publish(MyProducer, message)

  See Testing Guide for more explanation on testing producers and consumers.
  """
  @behaviour PubSub.Adapter

  alias PubSub.Adapter.Google
  alias PubSub.Message

  @impl PubSub.Adapter
  def publish(_topic, %Message{} = message) do
    # Verify encoding works
    {:ok, _encoded_message} = Message.encode(message)
    published_message = Google.set_published_meta(message, UUID.uuid4())
    {:ok, published_message}
  end

  @impl PubSub.Adapter
  def publish(_topic, [%Message{} | _others] = messages) do
    # Verify encoding works
    Enum.each(messages, fn message ->
      {:ok, _encoded_message} = Message.encode(message)
    end)

    ids = 1..Enum.count(messages)

    messages =
      messages
      |> Enum.zip(ids)
      |> Enum.map(fn {message, published_message_id} ->
        Google.set_published_meta(message, published_message_id)
      end)

    {:ok, messages}
  end

  @impl PubSub.Adapter
  defdelegate unpack(message), to: Google

  @impl PubSub.Adapter
  defdelegate unpack_metadata(message), to: Google

  @impl PubSub.Adapter
  defdelegate pack(acknowledger, batch_mode, message), to: Google

  @impl PubSub.Adapter
  def broadway_producer(_opts) do
    [module: {Broadway.DummyProducer, []}]
  end
end
