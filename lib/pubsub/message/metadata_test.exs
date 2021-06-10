defmodule GenesisPubSub.Message.MetadataTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.Message.Metadata
  alias GenesisPubSub.SchemaSpec

  setup_all do
    # simple agent that we can assign merge properties to
    {:ok, merge_agent} = Agent.start_link(fn -> %{} end)
    # lookup the agents state to get merge metadata
    # in each test we can change the agent state to update how the merge occurs
    # we shouldn't need to test the merging elsewhere so doing this update to application state should be fine
    Application.put_env(:genesis_pubsub, :merge_metadata, {Agent, :get, [merge_agent, fn state -> state end]})

    # cleanup application state
    on_exit(fn ->
      Application.delete_env(:genesis_pubsub, :merge_metadata)
    end)

    {:ok, merge_agent: merge_agent}
  end

  describe "new/1" do
    test "options are not required" do
      assert %Metadata{} = Metadata.new()
    end

    test "options can be passed" do
      %Metadata{} = meta = Metadata.new(%{correlation_id: "123", causation_id: "456", event_id: "abc"})
      assert %{correlation_id: "123", causation_id: "456", event_id: "abc"} = meta
    end

    test "merge_metadata mfa is invoked to get default metadata params", %{merge_agent: agent} do
      merge_props =
        Agent.get_and_update(agent, fn _current_state ->
          new_state = %{
            event_id: UUID.uuid4(),
            user: %{
              user_id: UUID.uuid4(),
              user_email: "example@example.com"
            }
          }

          {new_state, new_state}
        end)

      %Metadata{user: %Metadata.User{} = user} = meta = Metadata.new(%{})
      assert meta.event_id == merge_props.event_id
      assert user.user_id == merge_props.user.user_id
      assert user.user_email == merge_props.user.user_email
    end

    test "params passed to Metadata.new/2 override merge_metadata mfa", %{merge_agent: agent} do
      Agent.get_and_update(agent, fn _current_state ->
        new_state = %{
          user: %{
            user_id: UUID.uuid4(),
            user_email: "example@example.com"
          }
        }

        {new_state, new_state}
      end)

      override_id = UUID.uuid4()
      override_email = "overridden@example.com"

      %Metadata{user: %Metadata.User{} = user} =
        meta = Metadata.new(%{event_id: override_id, user: %{user_email: override_email}})

      assert meta.event_id == override_id
      assert user.user_email == override_email
    end

    test "invalid keys cause exceptions" do
      assert_raise KeyError, fn -> Metadata.new(%{non_existent_key: "hi"}) end
    end

    test "user metadata can be passed" do
      assert %Metadata{user: %Metadata.User{} = user} = Metadata.new(%{user: %{user_email: "bob@example.com"}})
      assert user.user_email == "bob@example.com"
    end
  end

  describe "follow/1" do
    test "correlation_id is copied to new metadata" do
      %{correlation_id: correlation} = previous = Metadata.new()
      assert %{correlation_id: ^correlation} = Metadata.follow(previous)
    end

    test "user is copied to new metadata" do
      user = %{
        user_id: UUID.uuid4(),
        bank_account_id: UUID.uuid4(),
        account_id: UUID.uuid4(),
        firebase_uid: UUID.uuid4(),
        user_email: "example@example.com"
      }

      previous = Metadata.new(%{user: user})
      assert %Metadata{user: %Metadata.User{} = followed_user} = Metadata.follow(previous)
      assert Map.get(followed_user, :user_id) == user.user_id
      assert Map.get(followed_user, :bank_account_id) == user.bank_account_id
      assert Map.get(followed_user, :account_id) == user.account_id
      assert Map.get(followed_user, :firebase_uid) == user.firebase_uid
      assert Map.get(followed_user, :user_email) == user.user_email
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
      user_id = UUID.uuid4()
      user_account_id = UUID.uuid4()
      user_bank_account_id = UUID.uuid4()
      user_firebase_uid = UUID.uuid4()
      user_email = "example@example.com"

      metadata =
        Metadata.new(%{
          adapter_event_id: event_id,
          correlation_id: correlation_id,
          causation_id: causation_id,
          service: service,
          topic: topic,
          user: %{
            user_id: user_id,
            account_id: user_account_id,
            bank_account_id: user_bank_account_id,
            firebase_uid: user_firebase_uid,
            user_email: user_email
          },
          schema: SchemaSpec.json(),
          created_at: created_at_string
        })

      encoded = Metadata.to_encodable(metadata)

      assert %{
               "schema_type" => "json",
               "user_id" => ^user_id,
               "user_account_id" => ^user_account_id,
               "user_bank_account_id" => ^user_bank_account_id,
               "user_firebase_uid" => ^user_firebase_uid,
               "user_email" => ^user_email,
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
      metadata =
        Metadata.new(%{adapter_event_id: UUID.uuid4(), schema: SchemaSpec.json(), published_at: DateTime.utc_now()})

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
