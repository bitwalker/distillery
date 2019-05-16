defmodule Distillery.Test.ShellTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Distillery.Releases.Shell
  
  describe "confirm/1" do
    test "can confirm with lowercase y" do
      capture_io("y", fn ->
        result = Shell.confirm?("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "can confirm with uppercase y" do
      capture_io("Y", fn ->
        result = Shell.confirm?("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "can confirm with yes" do
      capture_io("yes", fn ->
        result = Shell.confirm?("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "any other value results in a negative confirmation" do
      capture_io("foo", fn ->
        result = Shell.confirm?("yes/no?")
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, false}
    end
  end

  describe "confirm/3" do
    test "can confirm" do
      capture_io("yay", fn ->
        result = Shell.confirm?("do it?", "(y|n)ay:", ~r/^yay$/i)
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, true}
    end

    test "can cancel" do
      capture_io("nay", fn ->
        result = Shell.confirm?("do it?", "(y|n)ay:", ~r/^yay$/i)
        send(self(), {:confirmed?, result})
      end)

      assert_received {:confirmed?, false}
    end
  end

  describe "silent mode" do
    test "all output should be supressed" do
      Shell.configure(:silent)

      assert capture_io(fn ->
               Shell.debug("debug message")
             end) == ""

      assert capture_io(fn ->
               Shell.debugf("plain debug message")
             end) == ""

      assert capture_io(fn ->
               Shell.info("info message")
             end) == ""

      assert capture_io(fn ->
               Shell.success("success message")
             end) == ""

      assert capture_io(fn ->
               Shell.warn("warn message")
             end) == ""

      assert capture_io(fn ->
               Shell.notice("notice message")
             end) == ""

      assert capture_io(fn ->
               Shell.error("error message")
             end) == ""
    end
  end

  describe "quiet mode" do
    test "debug and info messages should be supressed" do
      Shell.configure(:quiet)

      assert capture_io(fn ->
               Shell.debug("debug message")
             end) == ""

      assert capture_io(fn ->
               Shell.debugf("plain debug message")
             end) == ""

      assert capture_io(fn ->
               Shell.info("info message")
             end) == ""
    end

    test "success, warnings, notices and errors should be logged" do
      Shell.configure(:quiet)

      assert capture_io(fn ->
               Shell.success("success message")
             end) =~
               "#{IO.ANSI.bright()}#{IO.ANSI.green()}==> success message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.warn("warn message")
             end) =~ "#{IO.ANSI.yellow()}==> warn message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.notice("notice message")
             end) =~ "#{IO.ANSI.yellow()}notice message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.error("error message")
             end) =~ "#{IO.ANSI.red()}==> error message\n#{IO.ANSI.reset()}"
    end
  end

  describe "normal mode" do
    test "debug messages should be supressed" do
      Shell.configure(:normal)

      assert capture_io(fn ->
               Shell.debug("debug message")
             end) == ""

      assert capture_io(fn ->
               Shell.debugf("debug message")
             end) == ""
    end

    test "everything else should be logged" do
      Shell.configure(:normal)

      assert capture_io(fn ->
               Shell.info("info message")
             end) =~ "#{IO.ANSI.bright()}#{IO.ANSI.cyan()}==> info message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.success("success message")
             end) =~
               "#{IO.ANSI.bright()}#{IO.ANSI.green()}==> success message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.warn("warn message")
             end) =~ "#{IO.ANSI.yellow()}==> warn message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.notice("notice message")
             end) =~ "#{IO.ANSI.yellow()}notice message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.error("error message")
             end) =~ "#{IO.ANSI.red()}==> error message\n#{IO.ANSI.reset()}"
    end
  end

  describe "verbose mode" do
    test "all messages should be logged" do
      Shell.configure(:verbose)

      assert capture_io(fn ->
               Shell.debug("debug message")
             end) =~ "#{IO.ANSI.cyan()}==> debug message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.debugf("debug message")
             end) =~ "#{IO.ANSI.cyan()}debug message#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.info("info message")
             end) =~ "#{IO.ANSI.bright()}#{IO.ANSI.cyan()}==> info message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.success("success message")
             end) =~
               "#{IO.ANSI.bright()}#{IO.ANSI.green()}==> success message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.warn("warn message")
             end) =~ "#{IO.ANSI.yellow()}==> warn message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.notice("notice message")
             end) =~ "#{IO.ANSI.yellow()}notice message\n#{IO.ANSI.reset()}"

      assert capture_io(fn ->
               Shell.error("error message")
             end) =~ "#{IO.ANSI.red()}==> error message\n#{IO.ANSI.reset()}"
    end
  end
end
