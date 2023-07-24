defmodule PubSub.Adapter.GoogleLocalTest do
  use ExUnit.Case, async: true
  import Hammox

  alias PubSub.Adapter.GoogleLocal
  alias PubSub.Support.TeslaHelper

  setup :verify_on_exit!

  describe "broadway_producer/1" do
    test "sets up topic and subscription" do
      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{method: :get, url: "http://localhost:8085/v1/projects/testing/topics/test-topic"}, [] ->
          TeslaHelper.response(
            status: 404,
            method: :get,
            body: "{\"error\":{\"code\":404,\"message\":\"Topic not found\",\"status\":\"NOT_FOUND\"}}"
          )
      end)
      |> expect(:call, fn
        %Tesla.Env{method: :put, url: "http://localhost:8085/v1/projects/testing/topics/test-topic"}, [] ->
          TeslaHelper.response(
            status: 200,
            method: :put,
            body: "{\"name\": \"projects/testing/topics/test-topic\"}"
          )
      end)
      |> expect(:call, fn
        %Tesla.Env{method: :get, url: "http://localhost:8085/v1/projects/testing/subscriptions/test-subscription"},
        [] ->
          TeslaHelper.response(
            status: 404,
            method: :get,
            body: "{\"error\":{\"code\":404,\"message\":\"Subscription not found\",\"status\":\"NOT_FOUND\"}}"
          )
      end)
      |> expect(:call, fn
        %Tesla.Env{method: :put, url: "http://localhost:8085/v1/projects/testing/subscriptions/test-subscription"},
        [] ->
          TeslaHelper.response(
            status: 200,
            method: :put,
            body:
              "{\"name\": \"projects/testing/subscriptions/test-subscription\",\"topic\": \"projects/testing/topics/test-topic\",\"pushConfig\": {},\"ackDeadlineSeconds\": 10,\"messageRetentionDuration\": \"604800s\"}"
          )
      end)

      assert [
               module:
                 {BroadwayCloudPubSub.Producer,
                  subscription: "projects/testing/subscriptions/test-subscription",
                  token_generator: {PubSub.Adapter.Google.TokenGenerator, :fetch_token, []}}
             ] ==
               GoogleLocal.broadway_producer(topic: "test-topic", subscription: "test-subscription")
    end

    test "topic and subscription already exist" do
      TeslaMock
      |> expect(:call, fn
        %Tesla.Env{method: :get, url: "http://localhost:8085/v1/projects/testing/topics/test-topic"}, [] ->
          TeslaHelper.response(
            status: 200,
            method: :get,
            body: "{\"name\": \"projects/testing/topics/test-topic\"}"
          )
      end)
      |> expect(:call, fn
        %Tesla.Env{method: :get, url: "http://localhost:8085/v1/projects/testing/subscriptions/test-subscription"},
        [] ->
          TeslaHelper.response(
            status: 200,
            method: :get,
            body:
              "{\"name\": \"projects/testing/subscriptions/test-subscription\",\"topic\": \"projects/testing/topics/test-topic\",\"pushConfig\": {},\"ackDeadlineSeconds\": 10,\"messageRetentionDuration\": \"604800s\"}"
          )
      end)

      assert [
               module:
                 {BroadwayCloudPubSub.Producer,
                  subscription: "projects/testing/subscriptions/test-subscription",
                  token_generator: {PubSub.Adapter.Google.TokenGenerator, :fetch_token, []}}
             ] ==
               GoogleLocal.broadway_producer(topic: "test-topic", subscription: "test-subscription")
    end

    test "raises on empty opts" do
      assert_raise KeyError, fn ->
        GoogleLocal.broadway_producer([])
      end
    end

    test "raises on missing topic" do
      assert_raise KeyError, fn ->
        GoogleLocal.broadway_producer(subscription: "test-subscription")
      end
    end

    test "raises on missing subscription" do
      assert_raise KeyError, fn ->
        GoogleLocal.broadway_producer(topic: "test-topic")
      end
    end
  end
end
