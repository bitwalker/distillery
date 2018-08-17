defmodule Distillery.Test.Tasks do
  @moduledoc false

  def run(argv) do
    IO.inspect(argv)
  end

  def run(arg1, arg2) do
    IO.inspect([arg1: arg1, arg2: arg2])
  end
end
