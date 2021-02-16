defmodule GenesisPubSub.Adapter do
  @moduledoc """
  External pubsub systems implemenations.

  ## Telemetry Events

  As well as implementing the callbacks in `GenesisPubSub.Adapter` a proper
  adapter needs to ensure that all telemetry events fired.
  `GenesisPubSub.Telemetry` contains helpers for telemetry events. See
  "Telemetry Events" guide for required telemetry events.

  """
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
  @callback test_message(module(), Message.published_t()) :: reference()
end
