defmodule Distillery.Test.CookiesTest do
  use ExUnit.Case, async: true
  use EQC.ExUnit

  @tag numtests: 100
  property "generated cookies are always valid" do
    forall cookie <- generated_cookie() do
      is_valid_cookie(cookie)
    end
  end

  test "can parse cookie via command line" do
    assert is_parsed_by_command_line(Distillery.Cookies.generate())
  end

  def generated_cookie() do
    lazy do
      Distillery.Cookies.generate()
    end
  end

  defp is_valid_cookie(x) when is_atom(x) do
    str = Atom.to_string(x)
    chars = String.to_charlist(str)

    with false <- String.contains?(str, ["-", "+", "'", "\"", "\\", "#", ","]),
         false <- Enum.any?(chars, fn b -> not (b >= ?! && b <= ?~) end),
         64 <- byte_size(str) do
      true
    else
      _ -> false
    end
  end

  defp is_valid_cookie(_x), do: false

  defp is_parsed_by_command_line(cookie) do
    cookie = Atom.to_string(cookie)

    case System.cmd("erl", ["-hidden", "-setcookie", cookie, "-noshell", "-s", "erlang", "halt"]) do
      {_, 0} -> true
      _ -> false
    end
  end
end
