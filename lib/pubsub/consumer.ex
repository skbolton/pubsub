defmodule GenesisPubSub.Consumer do
  @moduledoc """
  Consumer of messages to a given topic.
  """
  alias GenesisPubSub.Message
  alias GenesisPubSub.Message.Metadata

  @doc """
  Starts a Broadway consumer by passing opts to `use GenesisPubSub.Consumer`.

  All options from `Broadway.start_link/2` are available except for `producer` which
  is handled by passing in the opts used by the adapters through `c:GenesisPubSub.Adapter.broadway_producer/1`.
  For `batchers`, we will setup a default one with `batch_size: 10` and `batch_timeout: 2000`. You can override
  by passing your own `batchers` key or by passing just `batch_size` and `batch_timeout`.

  If you pass in your own `batchers` key make sure `batch_timeout` is set to `1` for tests
  otherwise you will force each test using your consumer to wait the full timeout for the
  `assert_receive`.

  ## Example

      use GenesisPubSub.Consumer,
        topic: "card-transactions.transaction-processed",
        subscription: "card-transactions.transaction-sanitization"

      def handle_message(processor_name, message, context) do
        allow(context, self())
        ...
      end

      def handle_batch(batch_name, messages, batch_info, context) do
        allow(context, self())
        ...
      end
  """
  defmacro __using__(use_opts) do
    quote do
      use Broadway

      def start_link(opts \\ []) do
        opts = Keyword.merge(unquote(use_opts), opts)
        test_mode? = Application.get_env(:genesis_pubsub, :test_mode?)

        producer =
          if test_mode?,
            do: [module: {Broadway.DummyProducer, []}],
            else: GenesisPubSub.adapter().broadway_producer(opts)

        batch_timeout =
          if test_mode?,
            do: 1,
            else: Keyword.get(opts, :batch_timeout, 2000)

        default_broadway_opts = [
          name: __MODULE__,
          producer: producer,
          processors: [default: []],
          batchers: [
            default: [
              batch_size: Keyword.get(opts, :batch_size, 10),
              batch_timeout: batch_timeout
            ]
          ]
        ]

        override_broadway_opts =
          Keyword.take(opts, [
            :name,
            :processors,
            :batchers,
            :context,
            :shutdown,
            :resubscribe_interval,
            :partition_by,
            :hibernate_after,
            :spawn_opt
          ])

        broadway_opts = Keyword.merge(default_broadway_opts, override_broadway_opts)

        Broadway.start_link(__MODULE__, broadway_opts)
      end

      defp allow(%{allow: allow}, pid) when is_function(allow), do: allow.(pid)
      defp allow(_context, _pid), do: :ok
    end
  end

  @spec unpack(Broadway.Message.t()) :: Message.published_t()
  @doc """
  Converts a `%Broadway.Message{}` into a `%Message{}` using configured adapter.
  See: `GenesisPubSub` configuration.
  """
  def unpack(%Broadway.Message{} = broadway_message) do
    adapter = GenesisPubSub.adapter()

    adapter.unpack(broadway_message)
  end

  @spec unpack_metadata(Broadway.Message.t()) :: Metadata.published_t()
  @doc """
  Converts a `%Broadway.Message{}` into a `%Metadata{}` using configured adapter.
  See: `GenesisPubSub` configuration.
  """
  def unpack_metadata(%Broadway.Message{} = broadway_message) do
    adapter = GenesisPubSub.adapter()

    adapter.unpack_metadata(broadway_message)
  end

  @spec test_message(module(), Message.published_t()) :: reference()
  @doc """
  Converts a message and sends it through `Broadway.test_message/3`.

  Broadway has testing utilities to generate broadway messages and send them
  through a pipeline as a way of testing consumers.

      Broadway.test_message(MyBroadwayConsumer, "some data", opts)

  This function wraps that utility by allowing the passing of a `Message` struct
  instead of data and options.

      message = Message.new(data: %{account_id: "123"})
      GenesisPubSub.Adapter.Google.test_message(MyBroadwayConsumer, message)

  Each adapter might store data differently in the metadata field of a broadway
  message so this callback allows an adapter to set up the broadway message to
  ensure that `unpack/1` will work on the produced broadway message.
  """
  def test_message(broadway_module, %Message{} = message) do
    adapter = GenesisPubSub.adapter()
    ref = make_ref()
    ack = {Broadway.CallerAcknowledger, {self(), ref}, :ok}

    broadway_message = adapter.pack(ack, :flush, message)

    :ok = Broadway.push_messages(broadway_module, [broadway_message])
    ref
  end

  @spec test_batch(module, [Message.published_t(), ...]) :: reference()
  @doc """
  Similar to `test_message/2` but for multiple messages.
  """
  def test_batch(broadway_module, messages) when is_list(messages) do
    adapter = GenesisPubSub.adapter()

    ref = make_ref()
    ack = {Broadway.CallerAcknowledger, {self(), ref}, :ok}

    broadway_messages = Enum.map(messages, &adapter.pack(ack, :bulk, &1))

    :ok = Broadway.push_messages(broadway_module, broadway_messages)
    ref
  end
end
