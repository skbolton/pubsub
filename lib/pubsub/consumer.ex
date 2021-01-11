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
end
