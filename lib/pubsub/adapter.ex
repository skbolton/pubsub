defmodule GenesisPubSub.Adapter do
  alias GenesisPubSub.Message
  alias GenesisPubSub.Producer

  @doc """
  Publishes a message through an external PubSub system and decorates message
  with publish time metadata.

  Messages can manage their own serialization. See: `Message.encode/1` for how
  to encode a message. Upon successful publishing of a message the `:event_id`
  and `:published_at` field should be added to message.

      %{data: encoded_data, metadata: encoded_meta} = Message.encode(message)
      # Publish through external system
      # ... snip ....
      # decorate message with additional metadata
      message = message
      |> Message.put_meta(:event_id, "unique identifier")
      |> Message.put_meta(:published_at, DateTime.utc_now())

      {:ok, message}
  """
  @callback publish(Producer.topic(), Message.unpublished_t()) ::
              {:ok, Message.published_t()} | {:error, any()}

  @callback publish(Producer.topic(), [Message.unpublished_t()]) ::
              {:ok, [Message.published_t()]} | {:error, any()}

  @doc """
  Convert a `Broadway.Message` into `GenesisPubSub.Message`.

  Each Adapter may publish message data and metadata into a slightly different
  shape. This callback maps Broadway messages into internal messages.
  """
  @callback unpack(Broadway.Message.t()) :: Message.published_t()
end
