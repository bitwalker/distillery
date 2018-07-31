defmodule Foo do
  def print_ok, do: IO.puts("ok from #{Node.self}")
end

Foo.print_ok
