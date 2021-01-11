defmodule GenesisPubSub.Message.MetadataTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Message.Metadata
  alias GenesisPubSub.SchemaSpec

  describe "new/1" do
    test "options are not required" do
      assert %Metadata{} = Metadata.new()
    end

    test "options can be passed" do
      %Metadata{} = meta = Metadata.new(%{correlation_id: "123", causation_id: "456", event_id: "abc"})
      assert %{correlation_id: "123", causation_id: "456", event_id: "abc"} = meta
    end

    test "invalid keys cause exceptions" do
      assert_raise KeyError, fn -> Metadata.new(%{non_existent_key: "hi"}) end
    end
  end

  describe "follow/1" do
    test "correlation_id is copied to new metadata" do
      %{correlation_id: correlation} = previous = Metadata.new()
      assert %{correlation_id: ^correlation} = Metadata.follow(previous)
    end

    test "previous metadata event_id becomes new metadata causation_id" do
      id = "123"
      previous = Metadata.new(%{event_id: id})
      assert %{causation_id: ^id} = Metadata.follow(previous)
    end
  end

  describe "to_encodable/1" do
    test "converts metadata into encodable map" do
      event_id = "1"
      created_at = DateTime.utc_now()
      created_at_string = DateTime.to_iso8601(created_at)
      correlation_id = UUID.uuid4()
      causation_id = UUID.uuid4()
      service = "testing"
      topic = "a-topic"

      metadata =
        Metadata.new(%{
          event_id: event_id,
          correlation_id: correlation_id,
          causation_id: causation_id,
          service: service,
          topic: topic,
          schema: SchemaSpec.json(),
          created_at: created_at_string
        })

      encoded = Metadata.to_encodable(metadata)

      assert %{
               "schema_type" => "json",
               "causation_id" => ^causation_id,
               "correlation_id" => ^correlation_id,
               "created_at" => ^created_at_string,
               "service" => ^service,
               "topic" => ^topic
             } = encoded
    end
  end

  describe "from_encodable/1" do
    setup do
      metadata = Metadata.new(%{event_id: UUID.uuid4(), schema: SchemaSpec.json(), published_at: DateTime.utc_now()})
      encoded = Metadata.to_encodable(metadata)

      {:ok, metadata: metadata, encoded_metadata: encoded}
    end

    test "all keys are present", %{metadata: metadata, encoded_metadata: encoded} do
      from_encodabled = Metadata.from_encodable(encoded)

      assert metadata
             |> Map.from_struct()
             |> Enum.all?(fn {key, value} ->
               Map.get(from_encodabled, key) == value
             end)
    end

    # certain adapters implementations might parse some of the metadata they receive
    # and have the created_at turned into a date time for them.
    test "created_at is passed as a DateTime", %{encoded_metadata: encoded} do
      {:ok, created_at, _offset} = DateTime.from_iso8601(encoded["created_at"])
      encoded = Map.put(encoded, "created_at", created_at)

      assert %Metadata{created_at: ^created_at} = Metadata.from_encodable(encoded)
    end

    # certain adapters implementations might parse some of the metadata they receive
    # and have the published_at turned into a date time for them.
    test "publised_at is passed as a DateTime", %{encoded_metadata: encoded} do
      {:ok, published_at, _offset} = DateTime.from_iso8601(encoded["published_at"])
      encoded = Map.put(encoded, "published_at", published_at)

      assert %Metadata{published_at: ^published_at} = Metadata.from_encodable(encoded)
    end

    test "schema spec gets properly de-serialized", %{metadata: metadata, encoded_metadata: encoded} do
      # json schema spec
      assert %{schema: %SchemaSpec{type: :json, properties: %{}}} = Metadata.from_encodable(encoded)
      # proto schema spec
      encoded = Metadata.to_encodable(Map.put(metadata, :schema, SchemaSpec.proto(Jason)))
      assert %{schema: %SchemaSpec{type: :proto, properties: %{encoder: Jason}}} = Metadata.from_encodable(encoded)
    end

    test "date values get cast to DateTime", %{encoded_metadata: encoded} do
      assert %{published_at: %DateTime{}, created_at: %DateTime{}} = Metadata.from_encodable(encoded)
    end
  end
end
