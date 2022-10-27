defmodule GenesisPubSub.Adapter.Google.MockTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Adapter.Google.Mock
  alias GenesisPubSub.Message
  alias GenesisPubSub.SchemaSpec

  describe "publish/2" do
    test "handles a single message" do
      message = Message.new(data: %{field: "value"}, metadata: %{schema: SchemaSpec.json()})

      assert {:ok, published} = Mock.publish("some-topic", message)
      assert Map.has_key?(published.metadata, :adapter_event_id)
      assert Map.has_key?(published.metadata, :published_at)
    end

    test "message is encoded to check for encoding errors" do
      bad_proto = TestProto.new(account_id: true)
      good_proto = TestProto.new(account_id: "123", name: "Randy Savage")

      # Genesis.Producer.publish adds the schema spec to messages
      # in these tests we need to add it manually
      assert_raise MatchError, fn ->
        Mock.publish("some-topic", Message.new(data: bad_proto, metadata: %{schema: SchemaSpec.proto(TestProto)}))
      end

      assert {:ok, _published} =
               Mock.publish(
                 "some-topic",
                 Message.new(data: good_proto, metadata: %{schema: SchemaSpec.proto(TestProto)})
               )
    end

    test "handles many messages" do
      # Genesis.Producer.publish adds the schema spec to messages
      # in these tests we need to add it manually though
      message = Message.new(data: %{field: "value"}, metadata: %{schema: SchemaSpec.json()})

      next_message =
        message
        |> Message.follow(include: [:field])
        |> Message.put_meta(:schema, SchemaSpec.json())

      assert {:ok, [first_published, second_published]} = Mock.publish("some-topic", [message, next_message])

      assert Map.has_key?(first_published.metadata, :adapter_event_id)
      assert Map.has_key?(second_published.metadata, :adapter_event_id)

      assert Map.has_key?(first_published.metadata, :published_at)
      assert Map.has_key?(second_published.metadata, :published_at)
    end
  end
end
