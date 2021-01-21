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
  Converts a message using configued adapter and sends it through
  `Broadway.test_message/3`.
  """
  def test_message(broadway_module, message) do
    adapter = GenesisPubSub.adapter()

    adapter.test_message(broadway_module, message)
  end
end
