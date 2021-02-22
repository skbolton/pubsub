defmodule GenesisPubSub.Adapter.GoogleTest do
  use ExUnit.Case, async: true
  import Tesla.Mock
  alias GenesisPubSub.Adapter.Google
  alias GenesisPubSub.Adapter.Google.LocalGoth
  alias GenesisPubSub.Message
  alias GenesisPubSub.Message.Metadata
  alias GenesisPubSub.SchemaSpec

  # In running system Goth would be used to get configuration and request tokens
  # Locally we use LocalGoth in Application env to not have to run Goth
  # It implements the needed API to mock Goth

  setup [:create_message, :encoded_message]

  describe "publish/2" do
    test "correct url is used", %{message: message} do
      {:ok, project_id} = LocalGoth.Config.get(:project_id)
      base_url = Google.base_url()
      topic = "a-topic"

      mock(fn %Tesla.Env{method: :post, url: url} = req ->
        assert url == "#{base_url}/v1/projects/#{project_id}/topics/#{topic}:publish"

        {:ok, req}
      end)

      Google.publish(topic, message)
    end

    test "token is retrieved with auth provider", %{message: message} do
      mock(fn %Tesla.Env{method: :post, headers: headers} = req ->
        assert Enum.find(headers, fn {key, value} -> key == "authorization" && value != nil end)

        {:ok, req}
      end)

      Google.publish("a-topic", message)
    end

    test "message gets shaped correctly to what google expects", %{message: message} do
      mock(fn %Tesla.Env{method: :post, body: body} = req ->
        body = Jason.decode!(body)

        # messages get sent under a messages key
        # metadata becomes attributes
        # data stays as data
        assert [%{"data" => _, "attributes" => _}] = body["messages"]

        {:ok, req}
      end)

      Google.publish("a-topic", message)
    end

    # google requires the data of a message to be encoded this way
    # this is in addition to the messages own encoding
    test "message data gets base64 encoded", %{message: message, encoded_message: encoded_message} do
      mock(fn %Tesla.Env{method: :post, body: body} = req ->
        body = Jason.decode!(body)

        [%{"data" => data}] = body["messages"]
        assert Base.decode64!(data) == encoded_message.data

        {:ok, req}
      end)

      Google.publish("a-topic", message)
    end

    test "publish time metadata gets set onto message", %{message: message} do
      event_id = "1"

      mock(fn %Tesla.Env{method: :post} ->
        json(%{messageIds: [event_id]})
      end)

      {:ok, message} = Google.publish("a-topic", message)
      assert %{metadata: %{event_id: ^event_id, published_at: %DateTime{}}} = message

      # also when there are multiple messages
      first_event = "2"
      second_event = "3"

      mock(fn %Tesla.Env{method: :post} ->
        json(%{messageIds: [first_event, second_event]})
      end)

      first_message = message
      second_message = Message.follow(message) |> Message.put_meta(:schema, SchemaSpec.json())

      {:ok, [message_one, message_two]} = Google.publish("a-topic", [first_message, second_message])

      assert %{metadata: %{event_id: ^first_event, published_at: %DateTime{}}} = message_one
      assert %{metadata: %{event_id: ^second_event, published_at: %DateTime{}}} = message_two
    end

    test "multiple messages are handled correctly", %{message: message} do
      next_message =
        Message.follow(message)
        |> Message.put_meta(:schema, SchemaSpec.json())

      mock(fn %Tesla.Env{method: :post, body: body} = req ->
        body = Jason.decode!(body)

        assert [%{"data" => _, "attributes" => _}, %{"data" => _, "attributes" => _}] = body["messages"]

        {:ok, req}
      end)

      Google.publish("a-topic", [message, next_message])
    end

    test "errors are propagated to the caller", %{message: message} do
      mock(fn %Tesla.Env{method: :post} ->
        # google uses 404 as a topic not found error
        %Tesla.Env{status: 404}
      end)

      assert {:error, %Tesla.Env{status: 404}} = Google.publish("a-topic", message)

      # When tesla blows up and we have no idea how to handle it
      mock(fn %Tesla.Env{method: :post} ->
        {:error, "kaboom"}
      end)

      assert {:error, "kaboom"} = Google.publish("a-topic", message)
    end
  end

  describe "unpack/1" do
    test "message is returned" do
      event_id = UUID.uuid4()
      published_at = DateTime.utc_now()

      message =
        Message.new(
          data: %{account_id: "123"},
          metadata: %{event_id: event_id, published_at: DateTime.utc_now(), schema: SchemaSpec.json()}
        )

      {:ok, %{data: data, metadata: meta}} = Message.encode(message)

      broadway_message = %Broadway.Message{
        data: data,
        metadata: %{attributes: meta, messageId: event_id, publishTime: DateTime.to_iso8601(published_at)},
        acknowledger: Broadway.NoopAcknowledger
      }

      %Message{data: data, metadata: metadata} = Google.unpack(broadway_message)
      assert %{"account_id" => "123"} = data
      assert %Metadata{published_at: ^published_at, event_id: ^event_id} = metadata
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
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.json(),
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
            published_at: DateTime.utc_now(),
            schema: SchemaSpec.proto(TestProto),
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
      event_id = json.metadata.event_id
      published_at = json.metadata.published_at
      correlation_id = json.metadata.correlation_id
      causation_id = json.metadata.causation_id
      topic = json.metadata.topic
      service = json.metadata.service

      message = Google.pack(acknowledger, batch_mode, json)
      # event id and publish time get put as top level keys in metadata
      assert %{metadata: %{messageId: ^event_id, publishTime: ^published_at, attributes: attrs}} = message
      # all other keys go in attributes as string keys
      assert %{
               "correlation_id" => ^correlation_id,
               "causation_id" => ^causation_id,
               "topic" => ^topic,
               "service" => ^service
             } = attrs

      # proto
      event_id = proto.metadata.event_id
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

  describe "telemetry events" do
    test "publish start/end is called properly for single message", %{message: message, test: test_name} do
      :telemetry.attach(
        "#{test_name}-start",
        [:genesis_pubsub, :publish, :start],
        &report_telemetry_received/4,
        nil
      )

      :telemetry.attach("#{test_name}-end", [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, nil)
      event_id = "1"
      topic = "a-topic"

      mock(fn %Tesla.Env{method: :post} ->
        json(%{messageIds: [event_id]})
      end)

      Google.publish(topic, message)

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements, %{messages: [^message], topic: ^topic}, nil}

      # verify that published message is sent through
      assert_receive {[:genesis_pubsub, :publish, :end], _measurements,
                      %{messages: [%{metadata: %{event_id: id}}], topic: ^topic}, nil}

      # verify that we sent published message through
      assert id != nil
    end

    test "publish start/end is called properly for multiple messages", %{message: message, test: test_name} do
      second_message = Message.follow(message) |> Message.put_meta(:schema, SchemaSpec.json())
      topic = "mutliple-messages-topic"

      :telemetry.attach(
        "#{test_name}-start",
        [:genesis_pubsub, :publish, :start],
        &report_telemetry_received/4,
        nil
      )

      :telemetry.attach("#{test_name}-end", [:genesis_pubsub, :publish, :end], &report_telemetry_received/4, nil)
      event_id_one = "1"
      event_id_two = "1"

      mock(fn %Tesla.Env{method: :post} ->
        json(%{messageIds: [event_id_one, event_id_two]})
      end)

      Google.publish(topic, [message, second_message])

      assert_receive {[:genesis_pubsub, :publish, :start], _measurements,
                      %{messages: [^message, ^second_message], topic: ^topic}, nil}

      # verify that published message is sent through
      assert_receive {[:genesis_pubsub, :publish, :end], _measurements,
                      %{
                        messages: [%{metadata: %{event_id: first_id}}, %{metadata: %{event_id: second_id}}],
                        topic: ^topic
                      }, nil}

      # verify that published messages were sent through telemetry
      assert first_id != nil
      assert second_id != nil
    end
  end

  # create example message for tests
  defp create_message(_context) do
    schema_spec = SchemaSpec.json()

    message =
      Message.new(data: %{account_id: "123", first_name: "Bob"})
      |> Message.put_meta(:schema, schema_spec)

    {:ok, message: message}
  end

  # encode data and metadata of message
  defp encoded_message(%{message: %Message{} = message}) do
    {:ok, %{data: _encoded_data, metadata: _encoded_meta} = encoded} = Message.encode(message)

    {:ok, encoded_message: encoded}
  end

  defp report_telemetry_received(event_name, measurments, context, config) do
    send(self(), {event_name, measurments, context, config})
  end
end
