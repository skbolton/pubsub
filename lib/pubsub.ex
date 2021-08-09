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

  To consume message we need to configure a consumer. Internally they are
  implemented as `Broadway` modules that you configure and define the callbacks
  for. The only extra step that is needed is to transform the `Broadway.Message`
  given to us in the callbacks into a `GenesisPubSub.Message`. This can be done
  by calling the `GenesisPubSub.Consumer.unpack/1` function in the callback. We
  want to work with `GenesisPubSub.Message` structs so that we can leverage the
  message workflows they provide. See `GenesisPubSub.Message.follow/2`

  Using the previous producer example that publishes account creation events we
  can create a consumer that would send out welcome emails as part of a marketing
  context.

      defmodule MyApp.Marketing.AccountCreatedConsumer do
        # all options accepted by `Broadway.start_link/2` can be passed here as well
        use GenesisPubSub.Consumer, topic: "topic-name", subscription: "subscription-name"

        alias Broadway.Message
        alias GenesisPubSub.Consumer
        alias GenesisPubSub.Message

        require Logger

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
  # credo:disable-for-next-line Credo.Check.Warning.MustNameUnderscoredVariables
  @type uuid :: <<_::288>>

  @doc """
  Returns configured json_codec library, defaulting to Jason.

    # config.exs
    config :genesis_pubsub, :json_codec, Poison

    GenesisPubSub.json_codec()
    Poison
  """
  def json_codec(), do: Application.get_env(:genesis_pubsub, :json_codec, Jason)

  @doc """
  Returns configured default service name.

    # config.exs
    config :genesis_pubsub, :service, "my-service"

    GenesisPubSub.service()
    "my-service"
  """
  def service(), do: Application.get_env(:genesis_pubsub, :service)

  @doc """
  Returns configured default adapter.

    # config.exs
    config :genesis_pubsub, :adapter, Google

    GenesisPubSub.adapter()
    Google
  """
  def adapter(), do: Application.get_env(:genesis_pubsub, :adapter)

  @doc """
  Returns configured merge_metadata mfa.

  This callback can be used to set metadata that will be merged on every message
  when `Message.new/1` is invoked. The values returned from this mfa will be
  merged with defaults values supplied by GenesisPubSub and then values supplied
  during `Message.new/1`. The merging happens in the following order:

  1. library defaults
  2. merge_metadata mfa
  3. params passed to `Message.new/1`

  See `GenesisPubSub.Message.Metadata.new/1` for more information on default
  params supplied by library.

  This is useful if you have a context that can be called into to extract values
  that you would want to add to every message. An example could be unpacking a
  JWT to get at user user information to then add to metadata's user params.
  Rather than having to manually add user information everywhere `Mssage.new/1`
  is called.

    # config.exs
    config :genesis_pubsub, :merge_metadata, {MyApp.Authentication, :merge_user_data, []}

    GenesisPubSub.merge_metadata()
    {MyApp.Authentication, :merge_jwt_params, []}
  """
  def merge_metadata() do
    # default mfa that just returns an empty map to merge in
    default_mfa = {Map, :new, []}
    Application.get_env(:genesis_pubsub, :merge_metadata, default_mfa)
  end
end
