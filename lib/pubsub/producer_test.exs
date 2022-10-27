defmodule GenesisPubSub.ProducerTest do
  use ExUnit.Case, async: true
  import Hammox
  alias GenesisPubSub.Adapter.Testing
  alias GenesisPubSub.Message
  alias GenesisPubSub.Producer
  alias GenesisPubSub.SchemaSpec

  setup :verify_on_exit!

  setup do
    valid_params = %{
      name: MyProducer,
      topic: "a-topic",
      schema: SchemaSpec.json()
    }

    {:ok, producer_params: valid_params}
  end

  describe "Producer configuration" do
    test "defaults from Application configuration get applied", %{producer_params: params} do
      service = Application.get_env(:genesis_pubsub, :service)
      adapter = Application.get_env(:genesis_pubsub, :adapter)

      config = Producer.Config.new(params)
      assert %Producer.Config{service: ^service, adapter: ^adapter, max_retry_duration: 0} = config
    end

    test "topic is a required option", %{producer_params: params} do
      without_topic = Map.delete(params, :topic)

      assert_raise ArgumentError, fn ->
        Producer.Config.new(without_topic)
      end
    end

    test "producer name is a required option", %{producer_params: params} do
      without_name = Map.delete(params, :name)

      assert_raise ArgumentError, fn ->
        Producer.Config.new(without_name)
      end
    end

    test "schema is a required option", %{producer_params: params} do
      without_schema = Map.delete(params, :schema)

      assert_raise ArgumentError, fn ->
        Producer.Config.new(without_schema)
      end
    end
  end

  describe "publishing through a producer" do
    setup do
      start_supervised!({
        Producer.Server,
        Producer.Config.new(%{name: MyProducer, topic: "a-topic", schema: SchemaSpec.json(), adapter: MockAdapter})
      })

      :ok
    end

    setup do
      message = Message.new()

      {:ok, message: message}
    end

    test "sending single message through adapter", %{message: message, producer_params: producer_params} do
      expect(MockAdapter, :publish, fn topic, message ->
        # keep same adapter behaviour contract
        Testing.publish(topic, message)
      end)

      Producer.publish(producer_params.name, message)
    end

    test "sending multiple messages through adapter", %{message: message, producer_params: producer_params} do
      messages = [message, Message.follow(message)]

      expect(MockAdapter, :publish, fn topic, [%Message{}, %Message{}] = message_list ->
        Testing.publish(topic, message_list)
      end)

      Producer.publish(producer_params.name, messages)
    end

    test "producer metadata is added to message", %{message: message, producer_params: producer_params} do
      # until sent through producer we don't know these values
      assert message.metadata.schema == nil
      assert message.metadata.topic == nil
      assert message.metadata.service == nil

      expect(MockAdapter, :publish, fn topic, message ->
        # once sent through producer values are added
        refute message.metadata.schema == nil
        refute message.metadata.topic == nil
        refute message.metadata.service == nil

        # keep same adapter behaviour contract
        Testing.publish(topic, message)
      end)

      Producer.publish(producer_params.name, message)
    end
  end

  describe "publish_with_retry/2" do
    setup do
      start_supervised!({
        Producer.Server,
        Producer.Config.new(%{
          name: MyProducer,
          topic: "a-topic",
          schema: SchemaSpec.json(),
          max_retry_duration: 15
        })
      })

      :ok
    end

    setup do
      message = Message.new()

      {:ok, message: message}
    end

    test "retries publish if failing until max retry duration is met", %{
      message: message,
      producer_params: producer_params
    } do
      # expect publish to only be called twice because third retry would exceed max_retry_durationmix f
      expect(MockAdapter, :publish, 2, fn _topic, _message ->
        {:error, :request_failed}
      end)

      assert {:error, :request_failed} = Producer.publish(producer_params.name, message)
    end

    test "retries stops when publish succeeds", %{
      message: message,
      producer_params: producer_params
    } do
      expect(MockAdapter, :publish, 1, fn _topic, _message ->
        {:error, :request_failed}
      end)

      expect(MockAdapter, :publish, 1, fn topic, message ->
        Testing.publish(topic, message)
      end)

      assert {:ok, %Message{}} = Producer.publish(producer_params.name, message)
    end

    test "only calls publish once if max retry duration is zero", %{message: message} do
      start_supervised!({
        Producer.Server,
        Producer.Config.new(%{
          name: NoRetryProducer,
          topic: "b-topic",
          schema: SchemaSpec.json(),
          max_retry_duration: 0
        })
      })

      expect(MockAdapter, :publish, 1, fn _topic, _message ->
        {:error, :request_failed}
      end)

      assert {:error, :request_failed} = Producer.publish(NoRetryProducer, message)
    end

    test "telemetry start is only fired once with retries", %{
      message: message,
      producer_params: producer_params,
      test: test_name
    } do
      :telemetry.attach(
        "#{test_name}-start",
        [:genesis_pubsub, :publish, :start],
        &report_telemetry_received/4,
        test_name
      )

      expect(MockAdapter, :publish, 1, fn _topic, _message ->
        {:error, :request_failed}
      end)

      expect(MockAdapter, :publish, 1, fn topic, message ->
        Testing.publish(topic, message)
      end)

      assert {:ok, %Message{}} = Producer.publish(producer_params.name, message)

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements, %{messages: [^message], topic: "a-topic"},
                      ^test_name}

      refute_receive {[:genesis_pubsub, :publish, :start], _measurements, %{messages: [^message], topic: "a-topic"},
                      ^test_name}
    end
  end

  describe "telemetry events" do
    setup do
      schema_spec = SchemaSpec.json()

      message =
        [data: %{account_id: "123", first_name: "Bob"}]
        |> Message.new()
        |> Message.put_meta(:schema, schema_spec)

      {:ok, message: message}
    end

    setup do
      start_supervised!({
        Producer.Server,
        Producer.Config.new(%{name: MyProducer, topic: "a-topic", schema: SchemaSpec.json()})
      })

      :ok
    end

    setup do
      stub(MockAdapter, :publish, &Testing.publish/2)

      :ok
    end

    test "publish start/end is called properly for single message", %{message: message, test: test_name} do
      :telemetry.attach(
        "#{test_name}-start",
        [:genesis_pubsub, :publish, :start],
        &report_telemetry_received/4,
        test_name
      )

      :telemetry.attach("#{test_name}-end", [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, test_name)

      assert {:ok, published_message} = Producer.publish(MyProducer, message)

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements, %{messages: [^message], topic: "a-topic"},
                      ^test_name}

      # verify that published message is sent through
      assert_receive {[:genesis_pubsub, :publish, :end], _measurements,
                      %{messages: [^published_message], topic: "a-topic"}, ^test_name}
    end

    test "publish start/end is called properly for multiple messages", %{message: message, test: test_name} do
      second_message = message |> Message.follow() |> Message.put_meta(:schema, SchemaSpec.json())

      :telemetry.attach(
        "#{test_name}-start",
        [:genesis_pubsub, :publish, :start],
        &report_telemetry_received/4,
        test_name
      )

      :telemetry.attach("#{test_name}-end", [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, test_name)

      assert {:ok, [published_message_one, published_message_two]} =
               Producer.publish(MyProducer, [message, second_message])

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements,
                      %{messages: [^message, ^second_message], topic: "a-topic"}, ^test_name}

      # verify that published message is sent through
      assert_receive {[:genesis_pubsub, :publish, :end], _measurements,
                      %{
                        messages: [
                          ^published_message_one,
                          ^published_message_two
                        ],
                        topic: "a-topic"
                      }, ^test_name}
    end

    test "publish_end is not called on error paths", %{message: message, test: test_name} do
      :telemetry.attach("#{test_name}-end", [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, test_name)

      expect(MockAdapter, :publish, 2, fn _topic, _message -> {:error, :kaboom} end)
      # test out both single and multiple message
      assert {:error, :kaboom} = Producer.publish(MyProducer, message)
      assert {:error, :kaboom} = Producer.publish(MyProducer, [message])

      # verify that published message is sent through
      refute_receive {[:genesis_pubsub, :publish, :end], _measurements, _context, ^test_name}
    end

    test "publish_failure is called on failed publish of single message", %{message: message, test: test_name} do
      :telemetry.attach(
        "#{test_name}-end",
        [:genesis_pubsub, :publish, :failure],
        &report_telemetry_received/4,
        test_name
      )

      expect(MockAdapter, :publish, fn _topic, _message -> {:error, :kaboom} end)
      assert {:error, :kaboom} = Producer.publish(MyProducer, message)

      assert_receive {
        [:genesis_pubsub, :publish, :failure],
        _measurements,
        %{topic: "a-topic", messages: [_message1], error: :kaboom},
        ^test_name
      }
    end

    test "publish_failure is called on failed publish of multiple messages", %{message: message, test: test_name} do
      second_message = message |> Message.follow() |> Message.put_meta(:schema, SchemaSpec.json())

      :telemetry.attach(
        "#{test_name}-end",
        [:genesis_pubsub, :publish, :failure],
        &report_telemetry_received/4,
        test_name
      )

      expect(MockAdapter, :publish, fn _topic, _message -> {:error, :kaboom} end)
      assert {:error, :kaboom} = Producer.publish(MyProducer, [message, second_message])

      assert_receive {
        [:genesis_pubsub, :publish, :failure],
        _measurements,
        %{topic: "a-topic", messages: [_message1, _message2], error: :kaboom},
        ^test_name
      }
    end
  end

  defp report_telemetry_received(event_name, measurments, context, config) do
    send(self(), {event_name, measurments, context, config})
  end
end
