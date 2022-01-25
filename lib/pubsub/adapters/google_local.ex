defmodule GenesisPubSub.Adapter.GoogleLocal do
  @moduledoc """
  Adapter for use with local dev. Delegates most functions to `GenesisPubSub.Adapter.Google`
  with the exception of `broadway_producer/1` which handles setting up the topics and subscriptions
  in the local environment.
  """
  @behaviour GenesisPubSub.Adapter

  alias GenesisPubSub.Adapter.Google
  alias GenesisPubSub.Adapter.Google.TokenGenerator
  alias GenesisPubSub.Adapter.GoogleLocal.Setup

  @impl GenesisPubSub.Adapter
  defdelegate publish(topic, messages), to: Google

  @impl GenesisPubSub.Adapter
  defdelegate unpack(message), to: Google

  @impl GenesisPubSub.Adapter
  defdelegate unpack_metadata(message), to: Google

  @impl GenesisPubSub.Adapter
  defdelegate pack(acknowledger, batch_mode, message), to: Google

  @impl GenesisPubSub.Adapter
  @doc """
  Returns the options necessary for the broadway producer key.

  Opts should have these two keys with string values:

  * `:topic`

  * `:subscription`
  """
  def broadway_producer(opts) do
    topic = Keyword.fetch!(opts, :topic)
    subscription = Keyword.fetch!(opts, :subscription)

    {:ok, %{name: name}} = Setup.ensure_subscription_exists(topic, subscription)

    [
      module: {
        BroadwayCloudPubSub.Producer,
        subscription: name, token_generator: {TokenGenerator, :fetch_token, []}
      }
    ]
  end
end
