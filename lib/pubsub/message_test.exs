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

  describe "follow/2" do
    # if following a json schema spec message the keys could be string keys
    # to make it so that the caller doesn't have to juggle this we can support
    # handling atom key maps or string key maps
    test "supports maps with string keys" do
      previous_message =
        Message.new(
          data: %{
            "key1" => "value",
            "key2" => "value",
            "key3" => "value",
            "key4" => "value"
          }
        )

      # using includes to copy only certain keys over
      assert %{data: %{key1: "value", key2: "value"}} = Message.follow(previous_message, include: [:key1, :key2])
      # try to include key that it doesn't have
      assert %{data: %{key1: "value", non_existent_key: nil}} =
               Message.follow(previous_message, include: [:key1, :non_existent_key])

      # using exclude to copy everything other than keys
      assert %{data: %{key3: "value", key4: "value"}} = Message.follow(previous_message, exclude: [:key1, :key2])
      # exclude a key thats not there anyways
      assert %{data: %{key3: "value", key4: "value"}} =
               Message.follow(previous_message, exclude: [:key1, :key2, :non_existent_key])
    end
  end
end
