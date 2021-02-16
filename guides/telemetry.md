# Telemetry

[Telemetry](https://github.com/beam-telemetry/telemetry) is the standard pattern for exposing application metrics in elixir projects. This guide will document the available events as well as showing examples of instrumenting metrics using the events.

## Events

* `[:genesis_pubsub, :publish, :start]` - dispatched when a pulish is started through adapter
  * Measurements - `%{system_time: system_time}`
  * Metdadata - `%{messages: [Message.unpublished_t(), ...], topic: String.t()}`
* `[:genesis_pubsub, :publish, :end]` - dispatched when a successful publish has occured
  * Measurements - `%{duration: native_time}`
  * Metdadata - `%{messages: [Message.published_t(), ...], topic: String.t()}`

## Examples

Logging latency around adapter publish timings.

```elixir
defmodule PubSubHandler do
  def handle_event([:genesis_pubsub, :publish, :end], %{duration: duration}, %{topic: topic}) do
    Logger.info("PubSub publish to topic: #{topic} took #{duration} milliseconds")
  end
end

:ok = :telemetry.attach("pubsub-publish-handler", [:genesis_pubsub, :publish, :end], &PubSubHandler/4, nil)
```
