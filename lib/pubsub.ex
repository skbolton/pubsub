defmodule GenesisPubSub do
  @moduledoc """
  GenesisPubSub is split into 3 main components:

    * `GenesisPubSub.Message` - messages are data transmitted between contexts.
      They model events that have occured that other contexts may be interested
      in.

    * `GenesisPubSub.Producer`- producers publish messages. Once a message has
      been produced it can not be reversed.

    * `GenesisPubSub.Consumer` - consumers process messages - possibly publishing
      new messages through producers.

  In order for these components to work they need an adapter to talk to an
  external pub/sub system. The available adapters are as follows.

    * `GenesisPubSub.Adapter.Google` - using google pubsub as an external system

    * `GenesisPubSub.Adapter.GoogleLocal` - for local dev, uses google pubsub (or emulator) and handles setup of topics and subscriptions

    * `GenesisPubSub.Adapter.Testing` - for debugging and testing

  > `GenesisPubSub.Adapter` has details around implementing new adapters.

  The following is a quick overview on how to get up and running. Not all options
  will be shown - consult each modules page for full rundown of its options and
  configuration.

  ## Configuration

  First, some top level configuration. This will set some defaults for
  producers.

      config :genesis_pubsub,
        # select an adapter
        adapter: GenesisPubSub.Adapter.Google,
        # select a service name to decorate message metadata with
        service: "a-service-name"

  > Adapters also contain their own configuration. Check their docs for the
  options they support.

  ## Producer

  Producers publish messages. They also define how a message is encoded. For
  every type of message that needs to be published a matching producer should be
  started. Include them somewhere in your supervision tree. See
  `GenesisPubSub.Producer.Config` for all the options available when starting a
  producer.

  To create a producer we will need a producer name, topic that it will
  publish to, and a schema specification for the messages it produces.

  > Note: the schema specification gets encoded into the message. This means that
  over the lifecyle of a producer it **can** change its schema spec without
  breaking any existing consumers.

      def start(_type, _args) do
        children = [
          {
            GenesisPubSub.Producer,
            GenesisPubSub.Producer.Config.new(%{
              name: AccountOpenedProducer,
              topic: "accounts-opened",
              schema: GenesisPubSub.SchemaSpec.json()
            })
          }
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  Now we can go ahead and create messages and publish them through our producer.

      account_opened = GenesisPubSub.Message.new(data: %{account_id: "123", first_name: "Bob"})
      GenesisPubSub.Producer.publish(AccountOpenedProducer, account_opened)

  `GenesisPubSub.Message` contains a lot of functions for getting messages into
  the proper shape.

  ## Consumer

  To consume messages we need to configure a consumer. Most of the heavy lifting
  is done by leveraging `Broadway`. The only extra step that is needed is to
  transform the `Broadway.Message` given to us by Broadway into a
  `GenesisPubSub.Message`. This can be done by calling the
  `GenesisPubSub.Consumer.unpack/1` function in our Broadway pipeline. We want to
  work with `GenesisPubSub.Message` structs so that we can leverage the message
  workflows they provide. See `GenesisPubSub.Message.follow/2`

  Using the previous producer example that publishes account creation events we
  can create a consumer that would send out welcome emails as part of a marketing
  context.

      defmodule MyApp.Marketing.AccountCreatedConsumer do
        use Broadway

        alias Broadway.Message
        alias GenesisPubSub.Consumer
        alias GenesisPubSub.Message

        require Logger

        def start_link(_opts) do
          Broadway.start_link(__MODULE__,
            name: __MODULE__,
            producer: Consumer.broadway_producer(topic: "topic-name", subscription: "subscription-name")
          )
        end

        # Note how we unpack the broadway message into a GenesisPubSub message
        def handle_message(_processor_name, message, _context) do
          :ok = message
          |> Consumer.unpack()
          |> process_message()

          message
        end

        def process_message(%Message{data: %{"account_id" => id, first_name: first_name} = data}) do
          Logger.info("Recieved account opened event: \#\{data}")
          # publish email somehow
          Marketing.Emails.send_welcome_email(%{account_id: id, first_name})
          :ok
        end

        def handle_batch(_batch_name, messages, _batch_info, _context) do
          messages
        end

      end

  That completes the loop of producing and consuming messages. Next suggested
  step would be to read the `GenesisPubSub.Message` documentation to understand
  message workflows.
  """
  @type uuid :: String.t()

  @doc "Returns configured json_codec library"
  def json_codec(), do: Application.get_env(:genesis_pubsub, :json_codec, Jason)

  @doc "Returns configured default service name"
  def service(), do: Application.get_env(:genesis_pubsub, :service)

  @doc "Returns configured default adapter"
  def adapter(), do: Application.get_env(:genesis_pubsub, :adapter)
end
