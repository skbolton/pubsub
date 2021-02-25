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
      assert %Producer.Config{service: ^service, adapter: ^adapter} = config
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
end
