defmodule Distillery.Test.Helpers do
  @moduledoc false

  @doc """
  When run in the context of a Mix project, runs `mix distillery.release` to build a release.
  
  Takes the following options:

    * `:verbose` - turns on verbose output, on by default when VERBOSE_TESTS is set
    * `:env` - set the release environment to build with
    * `:no_tar` - set whether or not to produce a tarball
    * `:upgrade` - set whether this is an upgrade release or not
  """
  def build_release(opts \\ []) do
    verbose? = 
      if Keyword.get(opts, :verbose, false) do
        true
      else
        System.get_env("VERBOSE_TESTS") != nil
      end
    env = Keyword.get(opts, :env, :prod)
    flags =
      if verbose? do
        ["--verbose", "--env=#{env}"]
      else
        ["--env=#{env}"]
      end
    flags =
      if Keyword.get(opts, :no_tar, false) do
        ["--no-tar" | flags]
      else
        flags
      end
    flags =
      if Keyword.get(opts, :upgrade, false) do
        ["--upgrade" | flags]
      else
        flags
      end
    mix("distillery.release", flags)
  end
  
  @doc """
  Executes a command using the release script at the path given and the given arguments.

  This is a wrapper around `exec` which handles the differences between Windows and non-Windows platforms
  """
  def release_cmd(bin, cmd, args \\ [])
  def release_cmd(bin, "start", _args) do
    case :os.type() do
      {:win32, _} ->
        # Install the release first
        case exec(bin, ["install"]) do
          {:ok, _} ->
            exec(bin, ["start"])
          other ->
            other
        end
      _ ->
        exec(bin, ["start"])
    end
  end
  def release_cmd(bin, "stop", _args) do
    case :os.type() do
      {:win32, _} ->
        case exec(bin, ["stop"]) do
          {:ok, _} ->
            exec(bin, ["uninstall"])
          other ->
            other
        end
      _ ->
        exec(bin, ["stop"])
    end
  end
  def release_cmd(bin, cmd, args) do
    exec(bin, [cmd | args])
  end

  @doc """
  Call Mix with the given arguments
  """
  def mix(command, args \\ []) do
    exec("mix", [command | args], env: [{"MIX_ENV", "prod"}])
  end

  @doc """
  Execute a command with the given arguments.

  Also accepts a list of options to pass to `System.cmd/3`
  
  If VERBOSE_TESTS is exported in the environment, relays all output to stdio
  """
  def exec(command, args \\ [], opts \\ []) do
    if System.get_env("VERBOSE_TESTS") do
      relative_cmd = Path.relative_to_cwd(command)
      IO.puts "exec: #{relative_cmd} with arguments #{inspect args}"
      opts = Keyword.merge(opts, [into: IORelay.new(:standard_io)])
      do_exec(command, args, opts)
    else
      do_exec(command, args, opts)
    end
  end
  
  defp do_exec(command, args, opts) do
    opts = Keyword.merge([stderr_to_stdout: true], opts)
    case System.cmd(command, args, opts) do
      {output, 0} when is_binary(output) ->
        {:ok, output}
        
      {output, non_zero_exit} when is_binary(output) ->
        {:error, non_zero_exit, output}

      {%IORelay{output: output}, 0} ->
        {:ok, output}

      {%IORelay{}, non_zero_exit} ->
        # No need to return the output, it is in standard out,
        # and we never match on the output of failed commands
        {:error, non_zero_exit, ""}
    end
  end
  
  @doc """
  Wait for VM and application to start
  """
  def wait_for_app(bin_path, timeout \\ 30_000) do
    parent = self()
    pid = spawn_link(fn -> ping_loop(bin_path, parent) end)
    do_wait_for_app(pid, timeout)
  end

  defp do_wait_for_app(pid, time_remaining) when time_remaining <= 0 do
    send(pid, :die)
    :timeout
  end

  defp do_wait_for_app(pid, time_remaining) do
    start = System.monotonic_time(:millisecond)

    if System.get_env("VERBOSE_TESTS") do
      IO.puts("Waiting #{time_remaining}ms for app..")
    end

    receive do
      {:ok, :pong} ->
        :ok

      _other ->
        ts = System.monotonic_time(:millisecond)
        do_wait_for_app(pid, time_remaining - (ts - start))
    after
      time_remaining ->
        send(pid, :die)
        :timeout
    end
  end

  defp ping_loop(bin_path, parent) do
    case exec(bin_path, ["ping"]) do
      {:ok, "pong\n"} ->
        send(parent, {:ok, :pong})

      {:error, _status, _output} ->
        receive do
          :die ->
            :ok
        after
          1_000 ->
            ping_loop(bin_path, parent)
        end
    end
  end
end
