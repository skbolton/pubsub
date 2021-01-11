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
end
