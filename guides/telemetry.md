# Telemetry

[Telemetry](https://github.com/beam-telemetry/telemetry) is the standard pattern for exposing application metrics in elixir projects. This guide will document the available events as well as showing examples of instrumenting metrics using the events.

## Events

* `[:pubsub, :publish, :start]` - dispatched when a pulish is started through adapter
  * Measurements - `%{system_time: system_time}`
  * Metdadata - `%{messages: [Message.unpublished_t(), ...], topic: String.t()}`
* `[:pubsub, :publish, :end]` - dispatched when a successful publish has occured
  * Measurements - `%{duration: native_time}`
  * Metdadata - `%{messages: [Message.published_t(), ...], topic: String.t()}`
* `[:pubsub, :publish, :failure]` - dispatched when publish is unsuccessful
  * Measurements - `%{}`
  * Metadata - `%{topic: String.t(), messages: [Message.unpublished_t(), ...], error: any()}`

## Examples

Logging latency around adapter publish timings.

```elixir
defmodule PubSubHandler do
  def handle_event([:pubsub, :publish, :end], %{duration: duration}, %{topic: topic}) do
    Logger.info("PubSub publish to topic: #{topic} took #{duration} milliseconds")
  end
end

:ok = :telemetry.attach("pubsub-publish-handler", [:pubsub, :publish, :end], &PubSubHandler/4, nil)
```
