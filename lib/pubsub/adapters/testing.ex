defmodule PubSub.Adapter.Testing do
  @behaviour PubSub.Adapter

  alias PubSub.Message
  alias PubSub.Message.Metadata
  alias PubSub.SchemaSpec

  require Logger

  @impl PubSub.Adapter
  def publish(_topic, [%Message{} | _rest] = messages) do
    published_messages =
      Enum.map(messages, fn message ->
        message
        |> Message.put_meta(:event_id, UUID.uuid4())
        |> Message.put_meta(:adapter_event_id, UUID.uuid4())
        |> Message.put_meta(:published_at, DateTime.utc_now())
      end)

    {:ok, published_messages}
  end

  @impl PubSub.Adapter
  def publish(_topic, %Message{} = message) do
    published_message =
      message
      |> Message.put_meta(:event_id, UUID.uuid4())
      |> Message.put_meta(:adapter_event_id, UUID.uuid4())
      |> Message.put_meta(:published_at, DateTime.utc_now())

    {:ok, published_message}
  end

  @impl PubSub.Adapter
  def unpack(%Broadway.Message{data: data} = message) do
    # for testing we just return any `Message.published_t()`
    Message.new(
      data: data,
      metadata: unpack_metadata(message)
    )
  end

  @impl PubSub.Adapter
  def unpack_metadata(_message) do
    # for testing we just return any `Message.published_t()`
    Metadata.new(%{
      event_id: UUID.uuid4(),
      adapter_event_id: UUID.uuid4(),
      created_at: DateTime.utc_now(),
      published_at: DateTime.utc_now(),
      topic: "a-topic",
      service: "testing",
      schema: SchemaSpec.json()
    })
  end

  @impl PubSub.Adapter
  def pack(acknowledger, batch_mode, %Message{} = message) do
    %Broadway.Message{
      data: message.data,
      metadata: message.metadata,
      acknowledger: acknowledger,
      batch_mode: batch_mode
    }
  end

  @impl PubSub.Adapter
  def broadway_producer(_opts) do
    [module: {Broadway.DummyProducer, []}]
  end
end
