defmodule GenesisPubSub.ConsumerTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Adapter.Local
  alias GenesisPubSub.Consumer
  alias GenesisPubSub.Message
  alias GenesisPubSub.SchemaSpec

  import Hammox

  setup :verify_on_exit!

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
        Local.unpack(broadway_message)
      end)

      Consumer.unpack(broadway_message)
    end
  end

  describe "test_message/2" do
    test "chosen adapter's test_message function is called" do
      # create a published message type
      message =
        Message.new(
          metadata: %{
            event_id: UUID.uuid4(),
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.json(),
            service: "testing",
            topic: "a topic"
          }
        )

      Hammox.expect(MockAdapter, :test_message, fn consumer, ^message ->
        assert consumer == GenesisPubSub.TestBroadwayConsumer
        # keep same contract
        make_ref()
      end)

      Consumer.test_message(GenesisPubSub.TestBroadwayConsumer, message)
    end
  end
end
