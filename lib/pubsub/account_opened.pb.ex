defmodule TestProto do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          account_id: String.t(),
          name: String.t()
        }

  defstruct [:account_id, :name]

  field(:account_id, 1, type: :string)
  field(:name, 2, type: :string)
end
