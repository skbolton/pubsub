defmodule GenesisPubSub.Consumer do
  @moduledoc """
  Consumer of messages to a given topic.
  """
  alias GenesisPubSub.Message
  @spec unpack(Broadway.Message.t()) :: Message.published_t()
  @doc """
  Converts a `%Broadway.Message{}` into a `%Message{}` using configured adapter.
  See: `GenesisPubSub` configuration.
  """
  def unpack(%Broadway.Message{} = broadway_message) do
    adapter = GenesisPubSub.adapter()

    adapter.unpack(broadway_message)
  end

  @spec test_message(module(), Message.published_t()) :: reference()
  @doc """
  Converts a message and sends it through `Broadway.test_message/3`.

  Broadway has testing utilities to generate broadway messages and send them
  through a pipeline as a way of testing consumers.

      Broadway.test_message(MyBroadwayConsumer, "some data", opts)

  This function wraps that utility by allowing the passing of a `Message` struct
  instead of data and options.

      message = Message.new(data: %{account_id: "123"})
      GenesisPubSub.Adapter.Google.test_message(MyBroadwayConsumer, message)

  Each adapter might store data differently in the metadata field of a broadway
  message so this callback allows an adapter to set up the broadway message to
  ensure that `unpack/1` will work on the produced broadway message.
  """
  def test_message(broadway_module, %Message{} = message) do
    adapter = GenesisPubSub.adapter()
    ref = make_ref()
    ack = {Broadway.CallerAcknowledger, {self(), ref}, :ok}

    broadway_message = adapter.pack(ack, :flush, message)

    :ok = Broadway.push_messages(broadway_module, [broadway_message])
    ref
  end

  @spec test_batch(module, [Message.published_t(), ...]) :: reference()
  @doc """
  Similar to `test_message/2` but for multiple messages.
  """
  def test_batch(broadway_module, messages) when is_list(messages) do
    adapter = GenesisPubSub.adapter()

    ref = make_ref()
    ack = {Broadway.CallerAcknowledger, {self(), ref}, :ok}

    broadway_messages = Enum.map(messages, &adapter.pack(ack, :bulk, &1))

    :ok = Broadway.push_messages(broadway_module, broadway_messages)
    ref
  end

  @spec broadway_producer(keyword()) :: keyword()
  @doc "Calls broadway_produer on the configured adapter, see `c:GenesisPubSub.Adapter.broadway_producer/1`"
  def broadway_producer(opts \\ []) do
    GenesisPubSub.adapter().broadway_producer(opts)
  end
end
