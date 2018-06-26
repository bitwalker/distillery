defmodule CtrlAppTest do
  use ExUnit.Case
  doctest CtrlApp

  test "greets the world" do
    assert CtrlApp.hello() == :world
  end
end
