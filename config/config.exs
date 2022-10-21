import Config

config :genesis_pubsub,
  json_codec: Jason,
  service: "testing",
  test_mode?: true,
  adapter: MockAdapter

config :genesis_pubsub, GenesisPubSub.Adapter.Google, auth_provider: GenesisPubSub.Adapter.Google.GothMock

config :tesla, adapter: TeslaMock

config :goth, disabled: true

config :google_api_pub_sub, base_url: System.get_env("PUBSUB_EMULATOR_HOST", "http://localhost:8085")
