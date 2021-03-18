defmodule GenesisPubSub.Adapter.Google.MockTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Adapter.Google.Mock
  alias GenesisPubSub.Message

  describe "publish/2" do
    test "handles a single message" do
      message = Message.new(data: %{field: "value"})

      assert {:ok, published} = Mock.publish("some-topic", message)
      assert Map.has_key?(published.metadata, :adapter_event_id)
      assert Map.has_key?(published.metadata, :published_at)
    end

    test "handles many messages" do
      message = Message.new(data: %{field: "value"})
      next_message = Message.follow(message, include: [:field])

      assert {:ok, [first_published, second_published]} = Mock.publish("some-topic", [message, next_message])

      assert Map.has_key?(first_published.metadata, :adapter_event_id)
      assert Map.has_key?(second_published.metadata, :adapter_event_id)

      assert Map.has_key?(first_published.metadata, :published_at)
      assert Map.has_key?(second_published.metadata, :published_at)
    end
  end
end
