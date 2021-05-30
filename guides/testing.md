# Testing PubSub

GenesisPubSub was designed to work well with [Mox](https://hexdocs.pm/mox) and the following guide will assume that you are somewhat familiar with it.

To start we need to update configuration options to support testing. First, we configure our `GenesisPubSub.Adapter` behaviour to be a Mox defined mock. This allows us to define expectations for how the adapter was called when testing Producers and Consumers. Next, we enable test_mode? which will help in testing our consumers. See "Consumers".

```elixir
# in some test support file
Mox.defmock(PubSubAdapterMock, for: GenesisPubSub.Adapter)

# config/test.exs
config :genesis_pubsub,
  adapter: PubSubAdapterMock,
  test_mode?: true
```

Also, each adapter provides a `Mock` version that keeps the same overall behaviour as the real adapter, without reaching out to any external system. This Mock can be great with Mox stubs or expectations to make sure that the correct values are being returned from Mox calls.

```elixir
# stubbing individual function
Mox.stub(PubSubAdapterMock, :publish, &GenesisPubSub.Adapter.Google.Mock.publish/2)

# stubbing all functions
Mox.stub_with(PubSubAdapterMock, GenesisPubSub.Adapter.Google.Mock)

# defining an expectation and using mock to return proper value
# for example if we want to assert we published to the right producer
Mox.expect(PubSubAdapterMock, :publish, fn MyProducer, message ->
  GenesisPubSub.Adapter.Google.Mock.publish(MyProducer, message)
end)
```

## Producers

Testing producers is pretty straight forward. To verify that we are producing to the correct topic or with proper payloads we can just set up a Mox expectation.

This means we can easily inspect the message and verify that we are producing things correctly.

```elixir
test "correct topic is published to" do
  Mox.expect(PubSubAdapterMock, :publish, fn producer, message ->
    assert message.metadata.topic = "expected-topic"
    # return proper value
    GenesisPubSub.Adapter.Google.Mock.publish(producer, message)
  end)

  BusinessLogic.execute()
end
```

## Consumers

Consumers add a little bit more complexity since they are defined as [Broadway](https://hexdocs.pm/broadway) pipelines with many processes involved. Mox stubs and assertions have to be [configured](https://hexdocs.pm/mox/Mox.html#module-multi-process-collaboration) to be shared between processes. The alternative is to use Mox global mode, but this causes you to need to run test in `async: false` - making tests run much slower. With a little extra work we can ensure that our tests can still run in parallel and we can define assertions on our mocks. With the `test_mode?` flag enabled in config we use the `DummyProducer` provided by Broadway and set `:batch_timeout` to `1` so that tests will not take longer than they should waiting for messages.

Our first step is making sure we can spawn unique versions of our broadway consumers for every test file. This means we need to specify a unique `name` option that we can get from the test.

```elixir
setup context do
  # context.test holds the name of each test, which has to be unique
  {:ok, pid} = MyApp.MyConsumer.start_link(name: context.test, context: %{allow: allow})

  {:ok, %{consumer: pid}}
end
```

With this a unique process exists that our pipeline is running in per test. The issue we now face is our test process being a separate one from the pipeline process. If we were to define expectations on our mock it would result in a Mox error since the other process is what is actually calling our mock.

```elixir
test "...", %{consumer: consumer}
  Mox.stub(PubSubAdapterMock, :unpack, &GenesisPubSub.Adapter.Google.Mock.unpack/1)

  # Mox will spit out an exception
  GenesisPubSub.Consumer.test_message(consumer, Message.new(...))
end
```

The solution is to pass a function that allows the processes we need to interact with our pipeline process. Broadway provides a `context` key that can be set on your consumer to store the function.

```elixir
setup context do
  :ok = Sandbox.checkout(Repo)

  # set self outside of function to get current process
  self = self()

  allow = fn pid ->
    :ok = Sandbox.allow(Repo, self, pid)
    Mox.allow(PubSubAdapterMock, self, pid)
  end

  {:ok, pid} = MyApp.MyConsumer.start_link(name: context.test, context: %{allow: allow})

  {:ok, %{consumer: pid}}
end
```

```elixir
defmodule MyApp.MyConsumer do
  use GenesisPubSub.Consumer, ...

  def handle_message(_processor, message, context) do
    allow(context, self())

    # other consumer logic ....
  end
end
```

## Running the Consumer

With the handling Mox multi process collaboration we can now focus on writing tests.

Broadway offers a `Broadway.test_message/2` function that can be passed a Broadway module and some data, it will then create a broadway message and send it through the pipeline. Our issue is that we also want all of the metadata in place for each message. It would be a pain to have to build this yourself. To help in this regard the `GenesisPubSub.Consumer.test_message/2` function exists. It also takes in a Broadway module but as the second argument it takes in a `GenesisPubSub.Message`. It will then do the work to get the message into the proper shape to run through the pipeline as a Broadway message.

```elixir
# be sure to be sharing expectations as described above
test "message is handled", context do
  # create a published message
  message = GenesisPubSub.Message.new(
    data: %{account_id: "123"},
    metadata: %{
      event_id: UUID.uuid4(),
      adapter_event_id: UUID.uuid4(),
      published_at: DateTime.utc_now(),
      service: "testing",
      topic: "some-topic",
      schema: GenesisPubSub.SchemaSpec.json()
    }
  )

  # now run it through our pipeline
  ref = GenesisPubSub.Consumer.test_message(context.test, message)
  assert_receive {:ack, ^ref, [_] = _successful, [] = _failed}, 2000
end
```

### Full Consumer example

```elixir
defmodule MyApp.MyConsumer do
  use GenesisPubSub.Consumer,
    topic: "card-transactions.transaction-processed",
    subscription: "card-transactions.transaction-sanitization"

  def handle_message(_processor, message, context) do
    allow(context, self())

    message
    |> GenesisPubSub.Consumer.unpack()
    |> BusinessLogic.execute()

    message
  end
end
```
