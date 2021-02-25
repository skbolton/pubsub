defmodule GenesisPubSub.Adapter.Google.GothMock do
  @moduledoc false

  # this module is just for testing purposes so that library doesn't need
  # goth configuration

  defmodule Config do
    @moduledoc false
    def get(:project_id) do
      {:ok, "testing"}
    end
  end

  defmodule Token do
    @moduledoc false
    def for_scope(_) do
      {:ok, %{type: "Bearer", token: "fake-token"}}
    end
  end
end
