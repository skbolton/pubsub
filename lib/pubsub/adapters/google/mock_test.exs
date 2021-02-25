defmodule GenesisPubSub.Adapter.Google.MockTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Adapter.Google.Mock
  alias GenesisPubSub.Message
  alias GenesisPubSub.SchemaSpec

  describe "publish/2" do
    test "handles a single message" do
      message = Message.new(data: %{field: "value"})

      assert {:ok, published} = Mock.publish("some-topic", message)
      assert Map.has_key?(published.metadata, :event_id)
      assert Map.has_key?(published.metadata, :published_at)
    end

    test "handles many messages" do
      message = Message.new(data: %{field: "value"})
      next_message = Message.follow(message, include: [:field])

      assert {:ok, [first_published, second_published]} = Mock.publish("some-topic", [message, next_message])

      assert Map.has_key?(first_published.metadata, :event_id)
      assert Map.has_key?(second_published.metadata, :event_id)

      assert Map.has_key?(first_published.metadata, :published_at)
      assert Map.has_key?(second_published.metadata, :published_at)
    end
  end

  describe "telemetry events" do
    setup do
      schema_spec = SchemaSpec.json()

      message =
        Message.new(data: %{account_id: "123", first_name: "Bob"})
        |> Message.put_meta(:schema, schema_spec)

      {:ok, message: message}
    end

    test "publish start/end is called properly for single message", %{message: message, test: test_name} do
      :telemetry.attach(
        "#{test_name}-start",
        [:genesis_pubsub, :publish, :start],
        &report_telemetry_received/4,
        nil
      )

      :telemetry.attach("#{test_name}-end", [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, nil)

      topic = "a-topic"

      Mock.publish(topic, message)

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements, %{messages: [^message], topic: ^topic}, nil}

      # verify that published message is sent through
      assert_receive {[:genesis_pubsub, :publish, :end], _measurements,
                      %{messages: [%{metadata: %{event_id: id}}], topic: ^topic}, nil}

      # verify that we sent published message through
      assert id != nil
    end

    test "publish start/end is called properly for multiple messages", %{message: message, test: test_name} do
      :telemetry.attach(
        "#{test_name}-start",
        [:genesis_pubsub, :publish, :start],
        &report_telemetry_received/4,
        nil
      )

      :telemetry.attach("#{test_name}-end", [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, nil)

      topic = "mutliple-messages-topic"
      second_message = Message.follow(message) |> Message.put_meta(:schema, SchemaSpec.json())
      Mock.publish(topic, [message, second_message])

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements,
                      %{messages: [^message, ^second_message], topic: ^topic}, nil}

      # verify that published message is sent through
      assert_receive {[:genesis_pubsub, :publish, :end], _measurements,
                      %{
                        messages: [%{metadata: %{event_id: first_id}}, %{metadata: %{event_id: second_id}}],
                        topic: ^topic
                      }, nil}

      # verify that published messages were sent through telemetry
      assert first_id != nil
      assert second_id != nil
    end
  end

  defp report_telemetry_received(event_name, measurments, context, config) do
    send(self(), {event_name, measurments, context, config})
  end
end
