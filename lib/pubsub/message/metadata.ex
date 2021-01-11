defmodule GenesisPubSub.Message.Metadata do
  @moduledoc """
  A Message's metadata helps correlate information about how a message was
  created and the flow that it was created in. Metadata is helpful in
  debugging and infrastructure of pubsub. For storing any domain information the
  `Message` data field should be used. Consumers of events should very rarely
  need to write metadata directly.

  Fields:

  * `event_id` - unique identifier for event.
    This field is assigned at publish time. Unpublished events will not contain
    this value.

  * `created_at` - UTC timestamp for when message was created

  * `published_at` - UTC timestamp for when message was published
    Also supllied at publish time.

  * `correlation_id` - id shared among events as part of a workflow
    As events are fired and responding to each other they all share the same
    `correlation_id`. Given this id you could retrieve all events that occured in
    a given action on the system.

  * `causation_id` - event id that caused this message to be created.
    When firing an event in response to consuming an event the previous event's
    `event_id` becomes the next events `causation_id`. Given all events by
    `correlation_id` they could be put in order by their `causation_id`. The
    first event having a nil `causation_id`.

  * `topic` - topic where message resides
    Supplied at publishing time by producer.

  * `schema` - schema information for how message can be encoded/decoded
    A `GenesisPubSub.SchemaSpec` struct supporting client side
    encoding/decoding. Assigned by Producer at publish time.

  * `service` - name of service or deployable responsible for dispatching event
    * Assigned by Producer at publish time.
  """
  alias GenesisPubSub.SchemaSpec

  defstruct [:event_id, :created_at, :published_at, :correlation_id, :causation_id, :topic, :schema, :service]

  @type unpublished_t :: %__MODULE__{
          event_id: nil,
          created_at: DateTime.t(),
          correlation_id: GenesisPubSub.uuid(),
          causation_id: GenesisPubSub.uuid() | nil,
          published_at: nil,
          schema: SchemaSpec.t(),
          service: String.t(),
          topic: String.t()
        }

  @type published_t :: %__MODULE__{
          event_id: GenesisPubSub.uuid(),
          created_at: DateTime.t(),
          correlation_id: GenesisPubSub.uuid(),
          # first event of a workflow would have nil causation
          # all following events should have one
          causation_id: GenesisPubSub.uuid() | nil,
          published_at: DateTime.t(),
          schema: SchemaSpec.t(),
          service: String.t(),
          topic: String.t()
        }

  @typedoc """
  Many pubsub systems don't support metadata that has any level of nesting. This
  type shows a message put into a flattened format as a plain map making it easy
  to serialize and publish through external systems.
  """
  @type encodable :: %{
          event_id: GenesisPubSub.uuid(),
          created_at: String.t(),
          correlation_id: GenesisPubSub.uuid(),
          causation_id: GenesisPubSub.uuid() | nil,
          published_at: String.t(),
          service: String.t(),
          topic: String.t(),
          schema_type: String.t(),
          schema_encoder: String.t() | nil
        }

  @doc "Creates new `Metadata` with default values applied"
  def new(meta_data \\ %{}) do
    params =
      %{
        correlation_id: UUID.uuid4(),
        created_at: DateTime.utc_now(),
        causation_id: nil
      }
      |> Map.merge(meta_data)

    struct!(__MODULE__, params)
  end

  @doc """
  Generates a new `Metadata` by following a previous events metadata.

  Many of the fields of the metadata are correlated to the event that preceeded
  it. This function helps line up the wires so that fields are correctly correlated.
  """
  def follow(%__MODULE__{} = previous_metadata) do
    # avoid copying other fields that are unique to previous metadata
    %__MODULE__{
      created_at: DateTime.utc_now(),
      correlation_id: previous_metadata.correlation_id,
      causation_id: previous_metadata.event_id
    }
  end

  @spec to_encodable(__MODULE__.published_t() | __MODULE__.unpublished_t()) :: encodable()
  @doc """
  Converts `metadata` into a serializable format.

  Most pubsub systems don't support nested maps in their metadata. This function
  ensures that a version of metadata exists that is completely flat and should
  be easily serializable with json.
  """
  def to_encodable(%__MODULE__{schema: %SchemaSpec{} = schema} = meta) do
    json_codec = GenesisPubSub.json_codec()
    # convert structs into encodable maps
    # this helps support more json protocols
    meta
    |> Map.from_struct()
    |> encode_schema(schema)
    |> Map.delete(:schema)
    # turn into json to stringify fields
    |> json_codec.encode!()
    # turn back into json map
    |> json_codec.decode!()
  end

  def encode(%__MODULE__{schema: nil} = meta) do
    json_codec = GenesisPubSub.json_codec()
    # convert structs into encodable maps
    # this helps support more json protocols
    meta
    |> Map.from_struct()
    |> Map.delete(:schema)
    # turn into json to stringify fields
    |> json_codec.encode!()
    # turn back into json map
    |> json_codec.decode!()
  end

  @spec from_encodable(encodable()) :: __MODULE__.published_t() | __MODULE__.published_t()
  @doc """
  Converts an encodable map into a `%Metadata{}`.
  """
  def from_encodable(encodable) do
    params =
      encodable
      # Ensure dates are DateTime and not string
      |> Map.update("created_at", nil, fn
        %DateTime{} = created_at ->
          created_at

        created_at when is_binary(created_at) ->
          {:ok, created_at, _offset} = DateTime.from_iso8601(created_at)
          created_at
      end)
      |> Map.update("published_at", nil, fn
        %DateTime{} = published_at ->
          published_at

        published_at when is_binary(published_at) ->
          {:ok, published_at, _offset} = DateTime.from_iso8601(published_at)
          published_at
      end)
      # deserialze schema fields into a spec
      |> case do
        %{"schema_type" => "proto", "schema_encoder" => encoder} = params ->
          Map.put(params, "schema", SchemaSpec.proto(String.to_atom(encoder)))

        %{"schema_type" => "json"} = params ->
          Map.put(params, "schema", SchemaSpec.json())
      end
      |> Map.take([
        "event_id",
        "created_at",
        "published_at",
        "correlation_id",
        "causation_id",
        "topic",
        "service",
        "schema"
      ])
      # Convert keys to atoms
      |> Enum.map(fn {key, value} -> {String.to_existing_atom(key), value} end)

    struct!(__MODULE__, params)
  end

  # serialized metadata needs to be a map of flat keys
  # turn schema into a flattened representation
  defp encode_schema(serialized_metadata_params, %SchemaSpec{type: :json}) do
    Map.put(serialized_metadata_params, :schema_type, :json)
  end

  defp encode_schema(serialized_metadata_params, %SchemaSpec{type: :proto, properties: %{encoder: encoder}}) do
    serialized_metadata_params
    |> Map.put(:schema_type, :proto)
    |> Map.put(:schema_encoder, encoder)
  end
end
