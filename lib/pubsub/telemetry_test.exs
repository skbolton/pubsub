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
      :telemetry.attach(test_name, [:pubsub, :publish, :start], &report_telemetry_received/4, test_name)
      messages = [Message.new()]
      topic = "a-topic"
      Telemetry.publish_start(topic, messages)

      assert_receive {[:pubsub, :publish, :start], _measurements, %{messages: ^messages, topic: ^topic}, ^test_name}
    end
  end

  describe "publish_end/2" do
    test "messages must be a list of messages" do
      assert_raise FunctionClauseError, fn ->
        Telemetry.publish_end(%{system_time: System.monotonic_time()}, "a-topic", Message.new())
      end
    end

    test "a duration is returned", %{test: test_name} do
      :telemetry.attach(test_name, [:pubsub, :publish, :end], &report_telemetry_received/4, test_name)
      Telemetry.publish_end(%{system_time: System.monotonic_time()}, "a-topic", [Message.new()])

      assert_receive {[:pubsub, :publish, :end], %{duration: duration}, _context, ^test_name}

      assert duration >= 0
    end

    test "messages and topic are included in context", %{test: test_name} do
      :telemetry.attach(test_name, [:pubsub, :publish, :end], &report_telemetry_received/4, test_name)
      topic = "a-topic"

      published_message =
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            schema: GenesisPubSub.SchemaSpec.json(),
            topic: topic,
            service: "a-service"
          }
        )

      Telemetry.publish_end(%{system_time: System.monotonic_time()}, topic, [published_message])

      assert_receive {[:pubsub, :publish, :end], _context, %{messages: [^published_message], topic: ^topic}, ^test_name}
    end
  end

  describe "publish_retry/2" do
    test "messages, topic, and total_delay are included", %{test: test_name} do
      :telemetry.attach(test_name, [:pubsub, :publish, :retry], &report_telemetry_received/4, test_name)
      topic = "a-topic"

      published_message =
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            schema: GenesisPubSub.SchemaSpec.json(),
            topic: topic,
            service: "a-service"
          }
        )

      Telemetry.publish_retry(topic, published_message, 10)

      assert_receive {[:pubsub, :publish, :retry], _context,
                      %{messages: [^published_message], topic: ^topic, total_delay: 10}, ^test_name}
    end

    test "messages can be a list or single message", %{test: test_name} do
      :telemetry.attach(test_name, [:pubsub, :publish, :retry], &report_telemetry_received/4, test_name)
      topic = "a-topic"

      published_message =
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            schema: GenesisPubSub.SchemaSpec.json(),
            topic: topic,
            service: "a-service"
          }
        )

      assert :ok = Telemetry.publish_retry(topic, published_message, 0)
      assert :ok = Telemetry.publish_retry(topic, [published_message], 0)
    end
  end

  defp report_telemetry_received(event_name, measurments, context, config) do
    send(self(), {event_name, measurments, context, config})
  end
end
