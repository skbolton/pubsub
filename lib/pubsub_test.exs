defmodule GenesisPubSubTest do
  use ExUnit.Case

  # see config.exs for where this value comes from
  test "retrieving json coded from Application env" do
    assert Jason == GenesisPubSub.json_codec()
  end

  # see config.exs for where this value comes from
  test "retrieving service name from Application env" do
    assert "testing" == GenesisPubSub.service()
  end

  # see config.exs for where this value comes from
  test "retrieving adapter from Application env" do
    assert MockAdapter = GenesisPubSub.adapter()
  end
end
