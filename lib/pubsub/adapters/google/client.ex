defmodule GenesisPubSub.Adapter.Google.HTTPClient do
  @moduledoc """
  REST client for communicating with Google Cloud PubSub.

  Docs: https://cloud.google.com/pubsub/docs/reference/rest
  """
  use Tesla

  alias GenesisPubSub.Adapter.Google
  alias GenesisPubSub.Producer
  alias GoogleApi.PubSub.V1.Api.Projects
  alias GoogleApi.PubSub.V1.Connection
  alias GoogleApi.PubSub.V1.Model.Subscription

  @type encoded_message :: %{
          data: String.t(),
          attributes: String.t()
        }

  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.KeepRequest)

  @spec publish(Producer.topic(), [encoded_message(), ...]) ::
          {:ok, %{messageIds: [String.t(), ...]}} | {:error, any()}
  def publish(topic, messages) when is_list(messages) do
    config = Module.concat(Google.auth_provider(), Config)

    with {:ok, project_id} <- config.get(:project_id),
         base_url <- base_url() do
      post(base_url <> "/v1/projects/#{project_id}/topics/#{topic}:publish", %{messages: messages}, headers: headers())
      |> parse_response()
    end
  end

  @spec publish(Producer.topic(), encoded_message()) ::
          {:ok, %{messageIds: [String.t(), ...]}} | {:error, any()}
  def publish(topic, message) do
    publish(topic, [message])
  end

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

  def list_subscriptions(opts \\ []) do
    config_mod = Module.concat(Google.auth_provider(), Config)

    with {:ok, project_id} <- config_mod.get(:project_id),
         connection <- google_conn() do
      Projects.pubsub_projects_subscriptions_list(connection, project_id, opts)
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

  defp base_url() do
    Application.get_env(:google_api_pub_sub, :base_url, "https://pubsub.googleapis.com")
  end

  defp headers() do
    token = Module.concat(Google.auth_provider(), Token)
    {:ok, %{type: type, token: token}} = token.for_scope("https://www.googleapis.com/auth/pubsub")

    [{"authorization", "#{type} #{token}"}]
  end

  defp parse_response({:ok, %Tesla.Env{status: status} = tesla_response}) when status not in 200..299,
    do: {:error, tesla_response}

  defp parse_response({:ok, %Tesla.Env{body: %{"messageIds" => message_ids}}}), do: {:ok, %{messageIds: message_ids}}

  defp parse_response({:error, _reason} = error), do: error

  defp google_conn() do
    token_mod = Module.concat(Google.auth_provider(), Token)
    {:ok, %{token: token}} = token_mod.for_scope("https://www.googleapis.com/auth/pubsub")
    Connection.new(token)
  end
end
