defmodule GenesisPubSub.TestBroadwayConsumer do
  @moduledoc false
  use Broadway

  def start_link(opts) do
    Broadway.start_link(__MODULE__,
      name: Keyword.get(opts, :name, __MODULE__),
      producer: [
        module: {Broadway.DummyProducer, []}
      ],
      processors: [
        default: [concurrency: 2]
      ]
    )
  end

  def handle_message(_processor, message, _context) do
    message
  end
end
