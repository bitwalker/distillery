defmodule InitTestAppTest do
  use ExUnit.Case
  doctest InitTestApp

  test "greets the world" do
    assert InitTestApp.hello() == :world
  end
end
