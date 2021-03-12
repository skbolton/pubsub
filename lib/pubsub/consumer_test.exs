defmodule GenesisPubSub.ConsumerTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Adapter.Testing
  alias GenesisPubSub.Consumer
  alias GenesisPubSub.Message
  alias GenesisPubSub.SchemaSpec

  import Hammox

  setup :verify_on_exit!

  setup context do
    _ = start_supervised!({GenesisPubSub.TestBroadwayConsumer, name: context.test})

    :ok
  end

  describe "unpack/1" do
    setup do
      broadway_message = %Broadway.Message{
        data: "test",
        metadata: %{attributes: %{}},
        acknowledger: {Broadway.NoopAcknowledger, "foo", "foo"}
      }

      {:ok, broadway_message: broadway_message}
    end

    test "chosen adapter's unpack function is called", %{broadway_message: broadway_message} do
      Hammox.expect(MockAdapter, :unpack, fn ^broadway_message ->
        Testing.unpack(broadway_message)
      end)

      Consumer.unpack(broadway_message)
    end
  end

  describe "test_message/2" do
    setup do
      message =
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.json(),
            service: "testing",
            topic: "a topic"
          }
        )

      {:ok, message: message}
    end

    test "the chosen adapters pack/2 function is called to convert to Broadway Message", %{
      test: test_name,
      message: message
    } do
      # for individual messages `:flush` is used over `:bulk` batch mode
      Hammox.expect(MockAdapter, :pack, fn acknowledger, :flush, ^message ->
        Testing.pack(acknowledger, :flush, message)
      end)

      Consumer.test_message(test_name, message)
    end

    # we need to ensure that the caller of `Consumer.test_message/2`
    # becomes the process we send acknowledgment events to so they
    # can test broadway pipelines
    test "acknowledger is setup to correctly bind to calling client", %{test: test_name, message: message} do
      client = self()

      Hammox.expect(MockAdapter, :pack, fn {Broadway.CallerAcknowledger, {^client, _ref}, :ok} = ack,
                                           :flush,
                                           ^message ->
        Testing.pack(ack, :flush, message)
      end)

      # do we receive ack events as clients
      ref = Consumer.test_message(test_name, message)
      assert_receive {:ack, ^ref, _successful, _failed}, 2000
    end
  end

  describe "test_batch/2" do
    setup do
      messages = [
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.json(),
            service: "testing",
            topic: "a topic"
          }
        ),
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.json(),
            service: "testing",
            topic: "a topic"
          }
        )
      ]

      {:ok, messages: messages}
    end

    test "the chosen adapters pack/2 function is called to for each message to convert to Broadway Message", %{
      test: test_name,
      messages: messages = [message1, message2]
    } do
      # when publishing multiple messages the `:bulk` batch mode is used
      Hammox.expect(MockAdapter, :pack, fn acknowledger, :bulk, ^message1 ->
        Testing.pack(acknowledger, :bulk, message1)
      end)

      Hammox.expect(MockAdapter, :pack, fn acknowledger, :bulk, ^message2 ->
        Testing.pack(acknowledger, :bulk, message2)
      end)

      Consumer.test_batch(test_name, messages)
    end

    # we need to ensure that the caller of `Consumer.test_message/2`
    # becomes the process we send acknowledgment events to so they
    # can test broadway pipelines
    test "acknowledger is setup to correctly bind to calling client", %{
      test: test_name,
      messages: messages = [message1, message2]
    } do
      client = self()

      Hammox.expect(MockAdapter, :pack, fn {Broadway.CallerAcknowledger, {^client, _ref}, :ok} = ack,
                                           :bulk,
                                           ^message1 ->
        Testing.pack(ack, :bulk, message1)
      end)

      Hammox.expect(MockAdapter, :pack, fn {Broadway.CallerAcknowledger, {^client, _ref}, :ok} = ack,
                                           :bulk,
                                           ^message2 ->
        Testing.pack(ack, :bulk, message2)
      end)

      # do we receive ack events as clients
      ref = Consumer.test_batch(test_name, messages)
      assert_receive {:ack, ^ref, _successful, _failed}, 2000
    end
  end
end
