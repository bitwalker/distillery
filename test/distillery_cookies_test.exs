defmodule Distillery.Cookies.Test do
  use ExUnit.Case, async: true
  use PropCheck

  @tag timeout: 180_000
  property "generated cookies are always valid", [:noshrink, :quiet] do
    numtests(100, forall c <- Distillery.Cookies.generate() do
      is_valid_cookie(c)
    end)
  end

  defp is_valid_cookie(x) when is_atom(x) do
    str = Atom.to_string(x)
    chars = String.to_charlist(str)
    with false <- String.contains?(str, ["-", "+", "'", "\"", "\\", "#"]),
         false <- Enum.any?(chars, fn b -> not (b >= ?! && b <= ?~) end),
         64 <- byte_size(str),
         true <- is_parsed_by_command_line(str) do
      true
    else
      _ -> false
    end
  end
  defp is_valid_cookie(_x), do: false

  defp is_parsed_by_command_line(cookie) do
    case System.cmd("erl", ["-hidden", "-setcookie", cookie, "-noshell", "-s", "init", "stop"]) do
      {_, 0} -> true
      _ -> false
    end
  end
end
