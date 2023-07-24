defmodule PubSubTest do
  use ExUnit.Case

  # see config.exs for where this value comes from
  test "retrieving json coded from Application env" do
    assert Jason == PubSub.json_codec()
  end

  # see config.exs for where this value comes from
  test "retrieving service name from Application env" do
    assert "testing" == PubSub.service()
  end

  # see config.exs for where this value comes from
  test "retrieving adapter from Application env" do
    assert MockAdapter = PubSub.adapter()
  end
end
