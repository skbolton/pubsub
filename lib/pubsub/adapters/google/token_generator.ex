defmodule GenesisPubSub.Adapter.Google.TokenGenerator do
  alias GenesisPubSub.Adapter.Google

  @scope "https://www.googleapis.com/auth/pubsub"

  def fetch_token() do
    token_mod = Module.concat(Google.auth_provider(), Token)

    with {:ok, token} <- token_mod.for_scope(@scope) do
      {:ok, token.token}
    end
  end
end
