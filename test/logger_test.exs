defmodule LoggerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Mix.Releases.Logger

  describe "silent mode" do
    test "non errors should be supressed" do
      Logger.configure(:silent)
      assert capture_io(fn ->
        Logger.debug("debug message")
      end) == ""
      assert capture_io(fn ->
        Logger.debug("plain debug message", :plain)
      end) == ""
      assert capture_io(fn ->
        Logger.info("info message")
      end) == ""
      assert capture_io(fn ->
        Logger.success("success message")
      end) == ""
      assert capture_io(fn ->
        Logger.warn("warn message")
      end) == ""
      assert capture_io(fn ->
        Logger.notice("notice message")
      end) == ""
    end

    test "errors should be logged" do
      Logger.configure(:silent)
      assert capture_io(fn ->
        Logger.error("error message")
      end) == "#{IO.ANSI.red}==> error message#{IO.ANSI.reset}\n"
    end
  end

  describe "quiet mode" do
    test "debug and info messages should be supressed" do
      Logger.configure(:quiet)
      assert capture_io(fn ->
        Logger.debug("debug message")
      end) == ""
      assert capture_io(fn ->
        Logger.debug("plain debug message", :plain)
      end) == ""
      assert capture_io(fn ->
        Logger.info("info message")
      end) == ""
    end

    test "success, warnings, notices and errors should be logged" do
      Logger.configure(:quiet)
      assert capture_io(fn ->
        Logger.success("success message")
      end) == "#{IO.ANSI.bright}#{IO.ANSI.green}==> success message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.warn("warn message")
      end) == "#{IO.ANSI.yellow}==> warn message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.notice("notice message")
      end) == "#{IO.ANSI.yellow}notice message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.error("error message")
      end) == "#{IO.ANSI.red}==> error message#{IO.ANSI.reset}\n"
    end
  end

  describe "normal mode" do
    test "debug messages should be supressed" do
      Logger.configure(:normal)
      assert capture_io(fn ->
        Logger.debug("debug message")
      end) == ""
      assert capture_io(fn ->
        Logger.debug("debug message", :plain)
      end) == ""
    end

    test "everything else should be logged" do
      Logger.configure(:normal)
      assert capture_io(fn ->
        Logger.info("info message")
      end) == "#{IO.ANSI.bright}#{IO.ANSI.cyan}==> info message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.success("success message")
      end) == "#{IO.ANSI.bright}#{IO.ANSI.green}==> success message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.warn("warn message")
      end) == "#{IO.ANSI.yellow}==> warn message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.notice("notice message")
      end) == "#{IO.ANSI.yellow}notice message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.error("error message")
      end) == "#{IO.ANSI.red}==> error message#{IO.ANSI.reset}\n"
    end
  end

  describe "verbose mode" do
    test "all messages should be logged" do
      Logger.configure(:verbose)
      assert capture_io(fn ->
        Logger.debug("debug message")
      end) == "#{IO.ANSI.cyan}==> debug message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.debug("debug message", :plain)
      end) == "#{IO.ANSI.cyan}debug message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.info("info message")
      end) == "#{IO.ANSI.bright}#{IO.ANSI.cyan}==> info message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.success("success message")
      end) == "#{IO.ANSI.bright}#{IO.ANSI.green}==> success message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.warn("warn message")
      end) == "#{IO.ANSI.yellow}==> warn message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.notice("notice message")
      end) == "#{IO.ANSI.yellow}notice message#{IO.ANSI.reset}\n"
      assert capture_io(fn ->
        Logger.error("error message")
      end) == "#{IO.ANSI.red}==> error message#{IO.ANSI.reset}\n"
    end
  end
end
