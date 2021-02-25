defmodule GenesisPubSub.Behaviour.Tesla do
  @callback get(Tesla.Env.client(), Tesla.Env.url()) :: Tesla.Env.result()
  @callback post(Tesla.Env.client(), Tesla.Env.url(), Tesla.Env.body(), list()) :: Tesla.Env.result()
  @callback call(Tesla.Env.t(), any()) :: Tesla.Env.result()
end
