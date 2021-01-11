defmodule GenesisPubSub.MessageTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Message

  doctest GenesisPubSub.Message

  describe "Message.new/1" do
    test "default metadata is applied" do
      %{metadata: %{correlation_id: correlation_id}} = Message.new()
      assert correlation_id != nil
    end

    test "only known metadata keys supported" do
      assert_raise KeyError, fn -> Message.new(metadata: %{non_existent_key: true}) end
    end

    test "supported metadata keys can be passed" do
      message = Message.new(metadata: %{correlation_id: "1"})

      assert message.metadata.correlation_id == "1"
    end
  end
end
