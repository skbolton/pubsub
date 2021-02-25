defmodule GenesisPubSub.Adapter.GoogleLocal.HTTPClient do
  @moduledoc """
  REST client for communicating with Google Cloud PubSub emulator.

  Docs: https://cloud.google.com/pubsub/docs/reference/rest
  """
  alias GenesisPubSub.Adapter.Google
  alias GenesisPubSub.Adapter.Google.HTTPClient, as: GoogleHTTPClient
  alias GoogleApi.PubSub.V1.Api.Projects
  alias GoogleApi.PubSub.V1.Connection
  alias GoogleApi.PubSub.V1.Model.Subscription

  defdelegate publish(topic, messages), to: GoogleHTTPClient

  def get_topic(topic_name) do
    config = Module.concat(Google.auth_provider(), Config)

    with {:ok, project_id} <- config.get(:project_id),
         connection <- google_conn() do
      Projects.pubsub_projects_topics_get(connection, project_id, topic_name)
    end
  end

  def create_topic(topic_name) do
    config = Module.concat(Google.auth_provider(), Config)

    with {:ok, project_id} <- config.get(:project_id),
         connection <- google_conn() do
      # must set a non empty body or pubsub complains
      Projects.pubsub_projects_topics_create(connection, project_id, topic_name, body: %{labels: %{local: true}})
    end
  end

  def get_subscription(subscription) do
    config_mod = Module.concat(Google.auth_provider(), Config)

    with {:ok, project_id} <- config_mod.get(:project_id),
         connection <- google_conn() do
      Projects.pubsub_projects_subscriptions_get(connection, project_id, subscription)
    end
  end

  def create_subscription(topic, subscription) do
    config_mod = Module.concat(Google.auth_provider(), Config)

    with {:ok, project_id} <- config_mod.get(:project_id),
         connection <- google_conn() do
      Projects.pubsub_projects_subscriptions_create(
        connection,
        project_id,
        subscription,
        body: %Subscription{topic: "projects/#{project_id}/topics/#{topic}"}
      )
    end
  end

  defp google_conn() do
    token_mod = Module.concat(Google.auth_provider(), Token)
    {:ok, %{token: token}} = token_mod.for_scope("https://www.googleapis.com/auth/pubsub")
    Connection.new(token)
  end
end
