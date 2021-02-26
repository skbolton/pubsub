defmodule GenesisPubSub.Adapter.Google do
  @moduledoc """
  `GenesisPubSub.Adapter` implementation using google cloud pubsub

  Docs: https://cloud.google.com/pubsub/docs

  ## Configuration

  The Google adapter has a few configuration options available that can be set
  through Application env. The following shows what the defaults are for the
  values.

      config :genesis_pubsub, GenesisPubSub.Adapter.Google
        auth_provider: Goth

  To change the base url you will need to set it on the google_api_pub_sub dep.

      config :google_api_pub_sub, base_url: "http://pubsub.google.com"

  To use the Google Adapter in the project either configure it as the adapter in
  GenesisPubSub env.

      config :genesis_pubsub,
        # ...snip....
        adapter: GenesisPubSub.Adapter.Google

  Or pass as option to a Producer:

      {:ok, _pid} = GenesisPubSub.Producer.start_link(
        GenesisPubSub.Producer.Config.new(%{
          # ...snip...
          adapter: GenesisPubSub.Adapter.Google
        })
      )

  Also, the Google adapter utilizes Tesla as an http client. Ensure that Tesla
  is using your preferred http adapter.

      config :tesla, adapter: Tesla.Adapter.Hackney

  """
  alias GenesisPubSub.Adapter.Google.HTTPClient
  alias GenesisPubSub.Message
  alias GenesisPubSub.Message.Metadata
  alias GenesisPubSub.SchemaSpec

  @behaviour GenesisPubSub.Adapter

  def auth_provider() do
    :genesis_pubsub
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:auth_provider, Goth)
  end

  @impl GenesisPubSub.Adapter
  def publish(topic, %Message{} = message) do
    publish_start = GenesisPubSub.Telemetry.publish_start(topic, [message])
    # encode message content
    {:ok, %{data: encoded_data, metadata: encoded_metadata}} = Message.encode(message)
    encoded_metadata = trim_nil_values(encoded_metadata)

    # convert to gcloud pubsub message shape
    # gcloud requires the payload to be Base64 encoded
    # metadata is also called attributes in their docs
    google_pubsub_message = %{data: Base.encode64(encoded_data), attributes: encoded_metadata}

    case HTTPClient.publish(topic, google_pubsub_message) do
      {:ok, %{messageIds: [published_message_id]}} ->
        # set publish-time metadata on each message
        published_message = set_published_meta(message, published_message_id)

        GenesisPubSub.Telemetry.publish_end(publish_start, topic, [published_message])
        {:ok, published_message}

      error ->
        error
    end
  end

  @impl GenesisPubSub.Adapter
  def publish(topic, [%Message{} | _others] = messages) do
    publish_start = GenesisPubSub.Telemetry.publish_start(topic, messages)

    encoded_messages =
      Enum.map(messages, fn message ->
        # encode message content
        {:ok, %{data: encoded_data, metadata: encoded_metadata}} = Message.encode(message)
        encoded_metadata = trim_nil_values(encoded_metadata)
        # convert to google pub sub message shape
        %{data: Base.encode64(encoded_data), attributes: encoded_metadata}
      end)

    case HTTPClient.publish(topic, encoded_messages) do
      {:ok, %{messageIds: published_message_ids}} ->
        # for each published message set publish-time metadata to original message
        messages =
          Enum.zip(messages, published_message_ids)
          |> Enum.map(fn {message, published_message_id} ->
            set_published_meta(message, published_message_id)
          end)

        GenesisPubSub.Telemetry.publish_end(publish_start, topic, messages)

        {:ok, messages}

      error ->
        error
    end
  end

  @impl GenesisPubSub.Adapter
  # gcloud pubsub calls metadata "attributes"
  # Broadway sticks it under a key of that name in metadata field
  def unpack(%Broadway.Message{
        data: data,
        metadata: %{messageId: event_id, publishTime: published_at, attributes: metadata_params}
      }) do
    # Google Pub/Sub sends published_at in milliseconds so we convert to microseconds
    # to be consistent with other timestamps
    {:ok, published_at, 0} = DateTime.from_iso8601(published_at)
    %{microsecond: {us, _precision}} = published_at
    published_at = %{published_at | microsecond: {us, 6}}

    metadata =
      metadata_params
      |> Map.put("event_id", event_id)
      |> Map.put("published_at", published_at)
      |> Metadata.from_encodable()

    # use schema spec to decode the data
    {:ok, decoded_data} = SchemaSpec.decode(metadata.schema, data)
    Message.new(data: decoded_data, metadata: Map.from_struct(metadata))
  end

  @impl GenesisPubSub.Adapter
  def pack(acknowledger, batch_mode, %Message{} = message) do
    {:ok, %{data: data, metadata: meta}} = Message.encode(message)

    attributes =
      meta
      |> Map.take(~w(correlation_id causation_id topic service schema_type schema_encoder))
      |> Enum.into(%{})

    broadway_metadata = %{
      # these keys are set as atoms in the top level metadata
      messageId: message.metadata.event_id,
      publishTime: message.metadata.published_at,
      # all other keys are set as string keys in an "attributes" map
      attributes: attributes
    }

    %Broadway.Message{data: data, metadata: broadway_metadata, acknowledger: acknowledger, batch_mode: batch_mode}
  end

  # gcloud pubsub doesn't support sending nil values at any of the attribute fields
  # having these fields missing in attributes won't cause any harm because
  # GenesisPubSub.Adapter.Google.unpack/1 will grab the values from the correct place
  # and build the message.
  defp trim_nil_values(map) do
    map
    |> Enum.filter(fn
      {_key, nil} -> false
      {_key, _value} -> true
    end)
    |> Enum.into(%{})
  end

  # adapters are responsible for setting the following metadata fields
  def set_published_meta(message, id) do
    message
    |> Message.put_meta(:event_id, id)
    |> Message.put_meta(:published_at, DateTime.utc_now())
  end

  @impl GenesisPubSub.Adapter
  @doc """
  Returns the options necessary for the broadway producer key.

  Only the `:subscription` opt is required, however, it is recommended to also set the `:topic` opt
  to be compatible with the `GenesisPubSub.Adapater.GoogleLocal` adapter to enable creating
  topics and subscriptions in dev environments.
  """
  def broadway_producer(opts) do
    config = Module.concat(auth_provider(), Config)
    {:ok, project_id} = config.get(:project_id)
    subscription = Keyword.fetch!(opts, :subscription)

    [
      module: {
        BroadwayCloudPubSub.Producer,
        subscription: "projects/#{project_id}/subscriptions/#{subscription}"
      }
    ]
  end
end
