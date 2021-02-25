defmodule GenesisPubSub.Adapter.Google.HTTPClient do
  @moduledoc """
  REST client for communicating with Google Cloud PubSub.

  Docs: https://cloud.google.com/pubsub/docs/reference/rest
  """
  use Tesla

  alias GenesisPubSub.Adapter.Google
  alias GenesisPubSub.Producer

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
end
