defmodule GenesisPubSub.Adapter.Local do
  alias GenesisPubSub.Message
  alias GenesisPubSub.SchemaSpec

  require Logger

  @behaviour GenesisPubSub.Adapter

  @impl GenesisPubSub.Adapter
  def publish(_topic, [%Message{} | _rest] = messages) do
    published_messages =
      Enum.map(messages, fn message ->
        message
        |> Message.put_meta(:event_id, UUID.uuid4())
        |> Message.put_meta(:published_at, DateTime.utc_now())
      end)

    {:ok, published_messages}
  end

  @impl GenesisPubSub.Adapter
  def publish(_topic, %Message{} = message) do
    published_message =
      message
      |> Message.put_meta(:event_id, UUID.uuid4())
      |> Message.put_meta(:published_at, DateTime.utc_now())

    {:ok, published_message}
  end

  @impl GenesisPubSub.Adapter
  def unpack(%Broadway.Message{data: data}) do
    # for testing we just return any `Message.published_t()`
    Message.new(
      data: data,
      metadata: %{
        event_id: UUID.uuid4(),
        created_at: DateTime.utc_now(),
        published_at: DateTime.utc_now(),
        topic: "a-topic",
        service: "testing",
        schema: SchemaSpec.json()
      }
    )
  end
end
