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
  alias GenesisPubSub.Telemetry

  @type topic :: String.t()

  @exponential_backoff_initial_delay 10
  @exponential_backoff_factor 2

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

      * `max_retry_duration` - max number of milliseconds that publish will retry if process fails
      Defaults to zero milliseconds (no retries)

    """
    @enforce_keys [:name, :topic, :schema, :adapter, :service, :max_retry_duration]
    defstruct [:name, :topic, :schema, :adapter, :service, :max_retry_duration]

    @type t :: %__MODULE__{
            name: String.t(),
            topic: Producer.topic(),
            schema: SchemaSpec.t(),
            adapter: module(),
            service: String.t(),
            max_retry_duration: non_neg_integer()
          }

    @doc "Creates a new Producer.Config applying defaults"
    def new(params) do
      params_with_defaults =
        params
        |> Map.put_new(:adapter, GenesisPubSub.adapter())
        |> Map.put_new(:max_retry_duration, 0)
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

    publish_start = Telemetry.publish_start(config.topic, [message])
    message = set_producer_meta(config, message)

    with {:ok, message} <- publish_with_retry(config, message) do
      Telemetry.publish_end(publish_start, config.topic, [message])
      {:ok, message}
    end
  end

  @spec publish(pid() | atom(), [Message.unpublished_t(), ...]) :: {:ok, [Message.published_t(), ...]}
  def publish(producer, [%Message{} | _rest] = messages) do
    %Config{} = config = Producer.Server.get_config(producer)
    publish_start = Telemetry.publish_start(config.topic, messages)
    messages_with_meta = Enum.map(messages, &set_producer_meta(config, &1))

    with {:ok, messages} = result <- publish_with_retry(config, messages_with_meta) do
      Telemetry.publish_end(publish_start, config.topic, messages)
      result
    end
  end

  @spec publish_with_retry(Config.t(), Message.unpublished_t() | [Message.unpublished_t(), ...]) ::
          {:ok, Message.published_t()} | {:ok, [Message.published_t(), ...]} | {:error, any()}
  defp publish_with_retry(config, message) do
    initial_state = {_last_result = nil, _initial_delay = 0}

    exponential_backoff()
    |> Enum.reduce_while(initial_state, fn
      new_delay, {last_result, accumulative_delay} when accumulative_delay + new_delay > config.max_retry_duration ->
        {:error, reason} = last_result
        Telemetry.publish_failure(config.topic, message, reason)
        {:halt, last_result}

      new_delay, {_last_result, accumulative_delay} ->
        :timer.sleep(new_delay)

        case config.adapter.publish(config.topic, message) do
          {:ok, _response} = success_response ->
            {:halt, success_response}

          error_response ->
            if new_delay >= @exponential_backoff_initial_delay do
              Telemetry.publish_retry(config.topic, message, accumulative_delay)
            end

            {:cont, {error_response, accumulative_delay + new_delay}}
        end
    end)
  end

  defp exponential_backoff() do
    Stream.unfold(0, fn
      0 ->
        {0, @exponential_backoff_initial_delay}

      last_delay ->
        {last_delay, round(last_delay * @exponential_backoff_factor)}
    end)
  end

  defp set_producer_meta(%Config{} = config, %Message{} = message) do
    message
    |> Message.put_meta(:schema, config.schema)
    |> Message.put_meta(:service, config.service)
    |> Message.put_meta(:topic, config.topic)
  end
end
