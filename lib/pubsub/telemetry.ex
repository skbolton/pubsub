defmodule GenesisPubSub.Telemetry do
  @moduledoc """
  Telemetry events emitter.
  """

  @type measurements :: %{system_time: integer()}

  @spec publish_start(GenesisPubSub.Producer.topic(), [GenesisPubSub.Message.unpublished_t(), ...]) :: measurements()
  @doc """
  Event for a publish start.

  `messages` should always be a list of messages even if only one message is
  being published. This makes writing telemetry handlers easier.

  A `measurements()` type is returned so that later the publsih_end event can be
  emitted and a duration timestamp can be calculated

      publish_started = GenesisPubSub.Telemetry.publish_start([messages])
      GenesisPubSub.Telemetry.publish_end(publish_started, [messages])
  """
  def publish_start(topic, messages) when is_list(messages) do
    measurements = %{system_time: System.monotonic_time()}
    :telemetry.execute([:genesis_pubsub, :publish, :start], measurements, %{messages: messages, topic: topic})

    measurements
  end

  @spec publish_end(measurements(), GenesisPubSub.Producer.topic(), [GenesisPubSub.Message.published_t()]) :: :ok
  @doc """
  Event for a publish end.

  Similarly to `publish_start/1` the `messages` will always be presented as a
  list. At this point they will also be published messages with full metadata available.
  """
  def publish_end(%{system_time: start_time}, topic, published_messages) when is_list(published_messages) do
    duration =
      System.monotonic_time()
      |> Kernel.-(start_time)
      |> System.convert_time_unit(:native, :millisecond)

    :telemetry.execute([:genesis_pubsub, :publish, :end], %{duration: duration}, %{
      messages: published_messages,
      topic: topic
    })
  end

  @spec publish_failure(GenesisPubSub.Producer.topic(), [GenesisPubSub.Message.unpublished_t(), ...], any()) :: :ok
  @doc """
  Event for errors on publishing `messages` through an adapter.
  """
  def publish_failure(topic, messages, error) do
    :telemetry.execute(
      [:genesis_pubsub, :publish, :failure],
      _measurements = %{},
      %{
        topic: topic,
        messages: messages,
        error: error
      }
    )
  end
end
