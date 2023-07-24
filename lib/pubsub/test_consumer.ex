defmodule PubSub.TestConsumer do
  @moduledoc false
  use PubSub.Consumer

  def handle_message(_processor, message, _context) do
    message
  end
end
