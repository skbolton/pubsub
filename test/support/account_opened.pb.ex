defmodule TestProto do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field(:account_id, 1, type: :string, json_name: "accountId")
  field(:name, 2, type: :string)
end
