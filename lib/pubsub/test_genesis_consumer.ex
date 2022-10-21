defmodule GenesisPubSub.TestGenesisConsumer do
  @moduledoc false
  use GenesisPubSub.Consumer

  def handle_message(_processor, message, _context) do
    message
  end
end
