defmodule GenesisPubSub.Adapter.Google.HTTPClientTest do
  use ExUnit.Case, async: true
  import Hammox

  alias GenesisPubSub.Adapter.Google.HTTPClient
  alias GenesisPubSub.Support.TeslaHelper

  setup :verify_on_exit!

  test "list_subscriptions/1" do
    response_body = %{
      "subscriptions" => [
        %{
          "ackDeadlineSeconds" => 10,
          "messageRetentionDuration" => "604800s",
          "name" => "projects/genesis-block-testing/subscriptions/card-transactions.transaction-processed.backup",
          "pushConfig" => %{},
          "topic" => "projects/genesis-block-testing/topics/card-transactions.transaction-processed"
        },
        %{
          "ackDeadlineSeconds" => 10,
          "messageRetentionDuration" => "604800s",
          "name" => "projects/genesis-block-testing/subscriptions/card-transactions.transaction-sanitization.backup",
          "pushConfig" => %{},
          "topic" => "projects/genesis-block-testing/topics/card-transactions.transaction-sanitization"
        },
        %{
          "ackDeadlineSeconds" => 10,
          "messageRetentionDuration" => "604800s",
          "name" => "projects/genesis-block-testing/subscriptions/card-transactions.transaction-sanitization",
          "pushConfig" => %{},
          "topic" => "projects/genesis-block-testing/topics/card-transactions.transaction-sanitization"
        }
      ]
    }

    TeslaMock
    |> expect(:call, fn
      %Tesla.Env{method: :get, url: "http://localhost:8085/v1/projects/testing/subscriptions"}, [] ->
        TeslaHelper.response(
          status: 200,
          method: :get,
          body: Jason.encode!(response_body)
        )
    end)

    assert {:ok,
            %GoogleApi.PubSub.V1.Model.ListSubscriptionsResponse{
              nextPageToken: nil,
              subscriptions: [
                %GoogleApi.PubSub.V1.Model.Subscription{
                  ackDeadlineSeconds: 10,
                  deadLetterPolicy: nil,
                  detached: nil,
                  enableMessageOrdering: nil,
                  expirationPolicy: nil,
                  filter: nil,
                  labels: nil,
                  messageRetentionDuration: "604800s",
                  name: "projects/genesis-block-testing/subscriptions/card-transactions.transaction-processed.backup",
                  pushConfig: %GoogleApi.PubSub.V1.Model.PushConfig{attributes: nil, oidcToken: nil, pushEndpoint: nil},
                  retainAckedMessages: nil,
                  retryPolicy: nil,
                  topic: "projects/genesis-block-testing/topics/card-transactions.transaction-processed"
                },
                %GoogleApi.PubSub.V1.Model.Subscription{
                  ackDeadlineSeconds: 10,
                  deadLetterPolicy: nil,
                  detached: nil,
                  enableMessageOrdering: nil,
                  expirationPolicy: nil,
                  filter: nil,
                  labels: nil,
                  messageRetentionDuration: "604800s",
                  name:
                    "projects/genesis-block-testing/subscriptions/card-transactions.transaction-sanitization.backup",
                  pushConfig: %GoogleApi.PubSub.V1.Model.PushConfig{attributes: nil, oidcToken: nil, pushEndpoint: nil},
                  retainAckedMessages: nil,
                  retryPolicy: nil,
                  topic: "projects/genesis-block-testing/topics/card-transactions.transaction-sanitization"
                },
                %GoogleApi.PubSub.V1.Model.Subscription{
                  ackDeadlineSeconds: 10,
                  deadLetterPolicy: nil,
                  detached: nil,
                  enableMessageOrdering: nil,
                  expirationPolicy: nil,
                  filter: nil,
                  labels: nil,
                  messageRetentionDuration: "604800s",
                  name: "projects/genesis-block-testing/subscriptions/card-transactions.transaction-sanitization",
                  pushConfig: %GoogleApi.PubSub.V1.Model.PushConfig{attributes: nil, oidcToken: nil, pushEndpoint: nil},
                  retainAckedMessages: nil,
                  retryPolicy: nil,
                  topic: "projects/genesis-block-testing/topics/card-transactions.transaction-sanitization"
                }
              ]
            }} = HTTPClient.list_subscriptions(fields: ["name", "topic"], pageSize: "1000")
  end
end
