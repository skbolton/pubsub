defmodule GenesisPubSub.Producer.Server do
  @moduledoc false
  use Agent
  alias GenesisPubSub.Producer.Config

  def child_spec(%Config{name: name} = config) do
    %{
      id: name,
      start: {__MODULE__, :start_link, [config]},
      type: :worker
    }
  end

  def start_link(%Config{name: name} = config) do
    Agent.start_link(fn -> config end, name: name)
  end

  def get_config(server) do
    Agent.get(server, & &1)
  end
end
