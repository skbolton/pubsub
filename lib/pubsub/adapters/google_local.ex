defmodule PubSub.Adapter.GoogleLocal do
  @moduledoc """
  Adapter for use with local dev. Delegates most functions to `PubSub.Adapter.Google`
  with the exception of `broadway_producer/1` which handles setting up the topics and subscriptions
  in the local environment.
  """
  @behaviour PubSub.Adapter

  alias PubSub.Adapter.Google
  alias PubSub.Adapter.Google.TokenGenerator
  alias PubSub.Adapter.GoogleLocal.Setup

  @impl PubSub.Adapter
  defdelegate publish(topic, messages), to: Google

  @impl PubSub.Adapter
  defdelegate unpack(message), to: Google

  @impl PubSub.Adapter
  defdelegate unpack_metadata(message), to: Google

  @impl PubSub.Adapter
  defdelegate pack(acknowledger, batch_mode, message), to: Google

  @impl PubSub.Adapter
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
