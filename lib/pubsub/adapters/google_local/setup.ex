defmodule PubSub.Adapter.GoogleLocal.Setup do
  @moduledoc """
  Module for communicating with google cloud to create topics and subscriptions
  on the fly.

  WARNING!: This is only for dev utilities. All topics and subscriptions should
  be created in terraform for production use.
  """
  alias PubSub.Adapter.Google.HTTPClient
  alias GoogleApi.PubSub.V1.Model.Subscription
  alias GoogleApi.PubSub.V1.Model.Topic

  @doc """
  Makes sure that topic exists.
  """
  def ensure_topic_exists(topic) do
    case HTTPClient.get_topic(topic) do
      {:ok, %Topic{}} = existed ->
        existed

      {:error, %Tesla.Env{status: 404}} ->
        HTTPClient.create_topic(topic)
    end
  end

  @doc """
  Makes sure that subscription and the topic it is subscribed to exist.
  """
  def ensure_subscription_exists(topic, subscription) do
    with {:ok, %Topic{}} <- ensure_topic_exists(topic) do
      case HTTPClient.get_subscription(subscription) do
        {:ok, %Subscription{}} = existed ->
          existed

        {:error, %Tesla.Env{status: 404}} ->
          HTTPClient.create_subscription(topic, subscription)
      end
    end
  end
end
