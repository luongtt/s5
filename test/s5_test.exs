defmodule S5Test do
  use ExUnit.Case
  doctest S5

  test "greets the world" do
    assert S5.hello() == :world
  end
end
