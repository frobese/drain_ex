defmodule StormexTest do
  use ExUnit.Case
  doctest Stormex

  test "greets the world" do
    assert Stormex.hello() == :world
  end
end
