defmodule GenesisPubSub.Producer do
  @moduledoc """
  Producer of messages to a topic

  Starting a producer, consider doing this in a supervision tree:

      {:ok, my_producer} = GenesisPubSub.Producer.start_link(Producer.Config.new(%{
        name: MyProducer,
        topic: "my-topic",
        schema: SchemaSpec.json(),
        adapter: GenesisPubSub.Adapter.Google
      }))

  Publishing through producer:

      GenesisPubSub.Producer.publish(MyProducer, Message.new())
  """
  alias GenesisPubSub.Message
  alias GenesisPubSub.Producer
  alias GenesisPubSub.SchemaSpec

  @type topic :: String.t()

  defmodule Config do
    @moduledoc """
    Configuration options for producers.

    The available options any there meanings are:

    * `name` - name of process. This name will be used when needing to publish
      through this producer.

    * `topic` - topic name producer produces to

    * `schema` - schema information for how encode/decode messages
      See `GenesisPubSub.SchemaSpec` for supported encoders.

    * `adapter` - module with `adapter` behaviour
      Defaults to `adapter` configured in Application env. See
      `GenesisPubSub`

    """
    @enforce_keys [:name, :topic, :schema, :adapter, :service]
    defstruct [:name, :topic, :schema, :adapter, :service]

    @type t :: %__MODULE__{
            name: String.t(),
            topic: Producer.topic(),
            schema: SchemaSpec.t(),
            adapter: module(),
            service: String.t()
          }

    @doc "Creates a new Producer.Config applying defaults"
    def new(params) do
      params_with_defaults =
        params
        |> Map.put_new(:adapter, GenesisPubSub.adapter())
        |> Map.put(:service, GenesisPubSub.service())

      struct!(__MODULE__, params_with_defaults)
    end
  end

  @doc false
  defdelegate child_spec(opts), to: Producer.Server

  def start_link(%Config{} = config) do
    Producer.Server.start_link(config)
  end

  @spec publish(pid() | atom(), Message.unpublished_t()) :: {:ok, Message.published_t()} | {:error, any()}
  @doc """
  Publish a single `message` or a list of `message` through `producer`.
  """
  def publish(producer, %Message{} = message) do
    %Config{} = config = Producer.Server.get_config(producer)

    message = set_producer_meta(config, message)
    config.adapter.publish(config.topic, message)
  end

  @spec publish(pid() | atom(), [Message.unpublished_t(), ...]) :: {:ok, [Message.published_t(), ...]}
  def publish(producer, [%Message{} | _rest] = messages) do
    %Config{} = config = Producer.Server.get_config(producer)
    messages_with_meta = Enum.map(messages, &set_producer_meta(config, &1))

    config.adapter.publish(config.topic, messages_with_meta)
  end

  defp set_producer_meta(%Config{} = config, %Message{} = message) do
    message
    |> Message.put_meta(:schema, config.schema)
    |> Message.put_meta(:service, config.service)
    |> Message.put_meta(:topic, config.topic)
  end
end
