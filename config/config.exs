import Config

config :genesis_pubsub,
  json_codec: Jason,
  service: "testing",
  adapter: MockAdapter

config :genesis_pubsub, GenesisPubSub.Adapter.Google, auth_provider: GenesisPubSub.Adapter.Google.LocalGoth

config :tesla, adapter: Tesla.Mock
