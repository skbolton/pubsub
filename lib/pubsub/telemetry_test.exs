defmodule GenesisPubSub.TelemetryTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Message
  alias GenesisPubSub.Telemetry

  describe "publish_start/1" do
    test "messages must be a list of messages" do
      assert_raise FunctionClauseError, fn ->
        Telemetry.publish_start("a-topic", Message.new())
      end
    end

    test "timestamp is returned" do
      assert %{system_time: start} = Telemetry.publish_start("a-topic", [Message.new()])
      assert is_integer(start)
    end

    test "messages and topic are included in context", %{test: test_name} do
      :telemetry.attach(test_name, [:genesis_pubsub, :publish, :start], &report_telemetry_received/4, nil)
      messages = [Message.new()]
      topic = "a-topic"
      Telemetry.publish_start(topic, messages)

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements, %{messages: ^messages, topic: ^topic}, nil}
    end
  end

  describe "publish_end/2" do
    test "messages must be a list of messages" do
      assert_raise FunctionClauseError, fn ->
        Telemetry.publish_end(%{system_time: System.monotonic_time()}, "a-topic", Message.new())
      end
    end

    test "a duration is returned", %{test: test_name} do
      :telemetry.attach(test_name, [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, nil)
      Telemetry.publish_end(%{system_time: System.monotonic_time()}, "a-topic", [Message.new()])

      assert_receive {[:genesis_pubsub, :publish, :end], %{duration: duration}, _context, nil}

      assert duration >= 0
    end

    test "messages and topic are included in context", %{test: test_name} do
      :telemetry.attach(test_name, [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, nil)
      topic = "a-topic"

      published_message =
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            schema: GenesisPubSub.SchemaSpec.json(),
            topic: topic,
            service: "a-service"
          }
        )

      Telemetry.publish_end(%{system_time: System.monotonic_time()}, topic, [published_message])

      assert_receive {[:genesis_pubsub, :publish, :end], _context, %{messages: [^published_message], topic: ^topic},
                      nil}
    end
  end

  defp report_telemetry_received(event_name, measurments, context, config) do
    send(self(), {event_name, measurments, context, config})
  end
end
