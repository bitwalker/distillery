defmodule Distillery.Test.IOTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "confirm/1" do
    test "can confirm with lowercase y" do
      capture_io("y", fn ->
        result = Distillery.IO.confirm("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "can confirm with uppercase y" do
      capture_io("Y", fn ->
        result = Distillery.IO.confirm("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "can confirm with yes" do
      capture_io("yes", fn ->
        result = Distillery.IO.confirm("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "any other value results in a negative confirmation" do
      capture_io("foo", fn ->
        result = Distillery.IO.confirm("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, false}
    end
  end

  describe "confirm/3" do
    test "can confirm" do
      capture_io("yay", fn ->
        result = Distillery.IO.confirm("do it?", "(y|n)ay:", ~r/^yay$/i)
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "can cancel" do
      capture_io("nay", fn ->
        result = Distillery.IO.confirm("do it?", "(y|n)ay:", ~r/^yay$/i)
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, false}
    end
  end
end
