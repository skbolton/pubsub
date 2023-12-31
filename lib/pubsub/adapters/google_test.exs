defmodule PubSub.Adapter.GoogleTest do
  use ExUnit.Case, async: true
  import Hammox

  alias PubSub.Adapter.Google
  alias PubSub.Message
  alias PubSub.Message.Metadata
  alias PubSub.SchemaSpec
  alias PubSub.Support.TeslaHelper

  setup [:create_message, :encoded_message, :verify_on_exit!]

  describe "publish/2" do
    test "token is retrieved with auth provider", %{message: message} do
      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{
          method: :post,
          url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish",
          headers: headers
        },
        [] ->
          assert Enum.find(headers, fn {key, value} -> key == "authorization" && value == "Bearer fake-token" end)

          TeslaHelper.response(
            status: 404,
            method: :post
          )
      end)

      Google.publish("a-topic", message)
    end

    test "message gets shaped correctly to what google expects", %{message: message} do
      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{
          method: :post,
          url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish",
          body: body
        },
        [] ->
          body = Jason.decode!(body)

          # messages get sent under a messages key
          # metadata becomes attributes
          # data stays as data
          assert [%{"data" => _data, "attributes" => _attributes}] = body["messages"]

          TeslaHelper.response(
            status: 404,
            method: :post
          )
      end)

      Google.publish("a-topic", message)
    end

    # google requires the data of a message to be encoded this way
    # this is in addition to the messages own encoding
    test "message data gets base64 encoded", %{message: message, encoded_message: encoded_message} do
      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{
          method: :post,
          url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish",
          body: body
        },
        [] ->
          body = Jason.decode!(body)

          [%{"data" => data}] = body["messages"]
          assert Base.decode64!(data) == encoded_message.data

          TeslaHelper.response(
            status: 404,
            method: :post
          )
      end)

      Google.publish("a-topic", message)
    end

    test "publish time metadata gets set onto message", %{message: message} do
      event_id = "1"

      # also when there are multiple messages
      first_event = "2"
      second_event = "3"

      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{
          method: :post,
          url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish"
        },
        [] ->
          TeslaHelper.response(
            status: 200,
            method: :post,
            body: %{"messageIds" => [event_id]}
          )
      end)
      |> expect(:call, fn
        %Tesla.Env{
          method: :post,
          url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish"
        },
        [] ->
          TeslaHelper.response(
            status: 200,
            method: :post,
            body: %{"messageIds" => [first_event, second_event]}
          )
      end)

      {:ok, message} = Google.publish("a-topic", message)
      assert %{metadata: %{adapter_event_id: ^event_id, published_at: %DateTime{}}} = message

      first_message = message
      second_message = message |> Message.follow() |> Message.put_meta(:schema, SchemaSpec.json())

      {:ok, [message_one, message_two]} = Google.publish("a-topic", [first_message, second_message])

      assert %{metadata: %{adapter_event_id: ^first_event, published_at: %DateTime{}}} = message_one
      assert %{metadata: %{adapter_event_id: ^second_event, published_at: %DateTime{}}} = message_two
    end

    test "multiple messages are handled correctly", %{message: message} do
      next_message =
        message
        |> Message.follow()
        |> Message.put_meta(:schema, SchemaSpec.json())

      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{method: :post, url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish", body: body},
        [] ->
          body = Jason.decode!(body)

          assert [%{"data" => _data1, "attributes" => _attributes1}, %{"data" => _data2, "attributes" => _attributes2}] =
                   body["messages"]

          TeslaHelper.response(
            status: 404,
            method: :post
          )
      end)

      Google.publish("a-topic", [message, next_message])
    end

    test "errors are propagated to the caller", %{message: message} do
      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{method: :post, url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish"}, [] ->
          TeslaHelper.response(
            status: 404,
            method: :post
          )
      end)
      |> expect(:call, fn
        %Tesla.Env{method: :post, url: "http://localhost:8085/v1/projects/testing/topics/a-topic:publish"}, [] ->
          {:error, "kaboom"}
      end)

      assert {:error, %Tesla.Env{status: 404}} = Google.publish("a-topic", message)

      assert {:error, "kaboom"} = Google.publish("a-topic", message)
    end
  end

  describe "unpack/1" do
    test "message is returned" do
      event_id = UUID.uuid4()
      %{microsecond: {us, _precision}} = published_at = DateTime.utc_now()
      google_formatted_published_at = published_at |> DateTime.truncate(:millisecond)

      truncated_microseconds = Integer.floor_div(us, 1000) * 1000
      truncated_microseconds_published_at = %{published_at | microsecond: {truncated_microseconds, 6}}

      message =
        Message.new(
          data: %{account_id: "123"},
          metadata: %{
            adapter_event_id: event_id,
            published_at: DateTime.utc_now(),
            user: %{
              user_id: UUID.uuid4(),
              account_id: UUID.uuid4()
            },
            schema: SchemaSpec.json()
          }
        )

      {:ok, %{data: data, metadata: meta}} = Message.encode(message)

      broadway_message = %Broadway.Message{
        data: data,
        metadata: %{attributes: meta, messageId: event_id, publishTime: google_formatted_published_at},
        acknowledger: Broadway.NoopAcknowledger
      }

      %Message{data: data, metadata: metadata} = Google.unpack(broadway_message)
      assert %{"account_id" => "123"} = data

      assert %Metadata{published_at: ^truncated_microseconds_published_at, adapter_event_id: ^event_id, user: user} =
               metadata

      assert user.user_id == message.metadata.user.user_id
      assert user.account_id == message.metadata.user.account_id
    end
  end

  describe "pack/1" do
    # message creation
    setup do
      json_message =
        Message.new(
          data: %{account_id: "123"},
          metadata: %{
            correlation_id: UUID.uuid4(),
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.json(),
            user: %{
              user_id: UUID.uuid4(),
              account_id: UUID.uuid4(),
              bank_account_id: UUID.uuid4(),
              firebase_uid: UUID.uuid4(),
              user_email: "example@example.com"
            },
            service: "testing",
            topic: "a-topic"
          }
        )

      proto_message =
        Message.new(
          data: TestProto.new(%{account_id: "123", name: "Bob"}),
          metadata: %{
            correlation_id: UUID.uuid4(),
            event_id: UUID.uuid4(),
            adapter_event_id: UUID.uuid4(),
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.proto(TestProto),
            user: %{
              user_id: UUID.uuid4(),
              account_id: UUID.uuid4(),
              bank_account_id: UUID.uuid4(),
              firebase_uid: UUID.uuid4(),
              user_email: "example@example.com"
            },
            service: "testing",
            topic: "a-different-topic"
          }
        )

      {:ok, json_message: json_message, proto_message: proto_message}
    end

    # acknowledger and batch mode
    setup do
      acknowledger = {Broadway.CallerAcknowledger, {self(), make_ref()}, :ok}

      {:ok, acknowledger: acknowledger, batch_mode: :flush}
    end

    test "acknowledger is set on message", %{acknowledger: acknowledger, batch_mode: batch_mode, json_message: message} do
      assert %Broadway.Message{acknowledger: ^acknowledger} = Google.pack(acknowledger, batch_mode, message)
    end

    test "batch_mode is set on message", %{acknowledger: acknowledger, json_message: message} do
      assert %Broadway.Message{batch_mode: :bulk} = Google.pack(acknowledger, :bulk, message)
      assert %Broadway.Message{batch_mode: :flush} = Google.pack(acknowledger, :flush, message)
    end

    test "data is set correctly", %{
      acknowledger: acknowledger,
      batch_mode: batch_mode,
      json_message: json,
      proto_message: proto
    } do
      # json message
      {:ok, %{data: data}} = Message.encode(json)
      %Broadway.Message{data: ^data} = Google.pack(acknowledger, batch_mode, json)

      # proto
      {:ok, %{data: data}} = Message.encode(proto)
      %Broadway.Message{data: ^data} = Google.pack(acknowledger, batch_mode, proto)
    end

    test "metadata is set correctly", %{
      acknowledger: acknowledger,
      batch_mode: batch_mode,
      json_message: json,
      proto_message: proto
    } do
      # json message
      event_id = json.metadata.adapter_event_id
      published_at = json.metadata.published_at
      correlation_id = json.metadata.correlation_id
      causation_id = json.metadata.causation_id
      topic = json.metadata.topic
      service = json.metadata.service
      user_id = json.metadata.user.user_id
      user_account_id = json.metadata.user.account_id
      user_bank_account_id = json.metadata.user.bank_account_id
      user_firebase_uid = json.metadata.user.firebase_uid
      user_email = json.metadata.user.user_email

      message = Google.pack(acknowledger, batch_mode, json)
      # event id and publish time get put as top level keys in metadata
      assert %{metadata: %{messageId: ^event_id, publishTime: ^published_at, attributes: attrs}} = message
      # all other keys go in attributes as string keys
      assert %{
               "correlation_id" => ^correlation_id,
               "causation_id" => ^causation_id,
               "topic" => ^topic,
               "service" => ^service,
               "user_id" => ^user_id,
               "user_account_id" => ^user_account_id,
               "user_bank_account_id" => ^user_bank_account_id,
               "user_firebase_uid" => ^user_firebase_uid,
               "user_email" => ^user_email
             } = attrs

      # proto
      event_id = proto.metadata.adapter_event_id
      published_at = proto.metadata.published_at
      correlation_id = proto.metadata.correlation_id
      causation_id = proto.metadata.causation_id
      topic = proto.metadata.topic
      service = proto.metadata.service

      message = Google.pack(acknowledger, batch_mode, proto)
      # same top level keys check as json
      assert %{metadata: %{messageId: ^event_id, publishTime: ^published_at, attributes: attrs}} = message
      # same attributes check as json
      assert %{
               "correlation_id" => ^correlation_id,
               "causation_id" => ^causation_id,
               "topic" => ^topic,
               "service" => ^service
             } = attrs
    end
  end

  describe "broadway_producer/1" do
    test "returns correct config" do
      assert [
               module:
                 {BroadwayCloudPubSub.Producer,
                  subscription: "projects/testing/subscriptions/test-subscription",
                  token_generator: {PubSub.Adapter.Google.TokenGenerator, :fetch_token, []}}
             ] ==
               Google.broadway_producer(subscription: "test-subscription")
    end

    test "raises on empty opts" do
      assert_raise KeyError, fn ->
        Google.broadway_producer([])
      end
    end

    test "raises on missing subscription" do
      assert_raise KeyError, fn ->
        Google.broadway_producer(topic: "test-topic")
      end
    end
  end

  # create example message for tests
  defp create_message(_context) do
    schema_spec = SchemaSpec.json()

    message =
      [data: %{account_id: "123", first_name: "Bob"}]
      |> Message.new()
      |> Message.put_meta(:schema, schema_spec)

    {:ok, message: message}
  end

  # encode data and metadata of message
  defp encoded_message(%{message: %Message{} = message}) do
    {:ok, %{data: _encoded_data, metadata: _encoded_meta} = encoded} = Message.encode(message)

    {:ok, encoded_message: encoded}
  end
end
