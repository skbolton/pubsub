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

  @type acknowledger :: {module(), ack_ref :: term(), data :: term()}
  @type batch_mode :: :bulk | :flush

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
  Convert a `GenesisPubSub.Message` into a `Broadway.Message`.

  This is used for testing to support the `Consumer.test_message/2` and
  `Consumer.test_batch/2` functions which take in a Message and dispatch
  it through a Broadway Pipeline. Since each adapter might shape metadata
  differently in a message this gives each adapter a chance to put things into
  the correct shape so that `c:unpack/1` will run properly.
  """
  @callback pack(acknowledger(), batch_mode(), Message.published_t()) :: Broadway.Message.t()

  @doc """
  Returns the options necessary for the broadway producer key.

  See docs in the adapter for opts values.
  """
  @callback broadway_producer(keyword()) :: keyword()
end
