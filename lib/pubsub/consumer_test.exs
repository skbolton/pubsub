defmodule GenesisPubSub.ConsumerTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Adapter.Local
  alias GenesisPubSub.Consumer

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
end
