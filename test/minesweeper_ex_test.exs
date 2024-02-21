defmodule MinesweeperExTest do
  use ExUnit.Case
  doctest MinesweeperEx

  test "greets the world" do
    assert MinesweeperEx.hello() == :world
  end
end
