defmodule Distillery.Test.Runtime.CLI do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Releases.Runtime.Control

  setup_all do
    :rand.seed(:exs64)
    Application.put_env(:artificery, :no_halt, true)
    boot_server = :"test_cli@127.0.0.1"
    :ok = start_boot_server(boot_server)
    tab = :ets.new(__MODULE__, [:public, :set])
    :ets.insert_new(tab, {:counter, 1})
    %{table: tab}
  end
  
  setup %{table: tab} do
    id = :ets.update_counter(tab, :counter, 1)
    peer = :"test_cli_slave#{id}@127.0.0.1"
    [:ok] = spawn_nodes([peer])
    %{node: peer}
  end

  describe "when pinging a node" do
    test "prints pong when available", %{node: peer} do
      assert is_success(fn ->
        Control.main(["--verbose", "ping", "--cookie", "#{Node.get_cookie}", "--peer", "#{peer}"])
      end) == "pong\n"
    end

    test "prints friendly error (and pang) when unavailable" do
      assert is_failure(fn ->
        Control.main(["--verbose", "ping", "--cookie", "#{Node.get_cookie}", "--peer", "missingno@127.0.0.1"])
      end) =~ "Received 'pang' from missingno@127.0.0.1!\n"
    end

    test "omitting required flag produces friendly error", %{node: peer} do
      assert is_failure(fn ->
        Control.main(["--verbose", "ping", "--peer", "#{peer}"])
      end) =~ "Missing required flag '--cookie'."
    end
  end

  describe "rpc/eval" do
    test "eval is executed locally" do
      assert is_success(fn ->
        Control.main(["eval", "IO.puts \"Hello from \" <> to_string(Node.self) <> \"!\""])
      end) =~ "Hello from test_cli@127.0.0.1!"
    end

    test "eval --file" do
      assert is_success(fn ->
        Control.main(["eval", "--file", Path.join([__DIR__, "support", "eval_file_test.exs"]) |> Path.expand])
      end) =~ "ok from test_cli@127.0.0.1\n"
    end

    test "eval syntax error produces friendly error" do
      assert is_failure(fn ->
        Control.main(["eval", "div(2, 0)"])
      end) =~ "Evaluation failed with: bad argument in arithmetic expression"
    end

    test "rpc is executed remotely", %{node: peer} do
      assert is_success(fn ->
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "IO.puts \"Hello from \" <> to_string(Node.self) <> \"!\""])
      end) =~ ~r/Hello from test_cli_slave\d+@127.0.0.1!/
    end

    test "rpc --file", %{node: peer} do
      assert is_success(fn ->
        path = Path.join([__DIR__, "support", "eval_file_test.exs"]) |> Path.expand
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "--file", path])
      end) =~ ~r/ok from test_cli_slave\d+@127.0.0.1\n/
    end

    test "rpc error produces friendly error", %{node: peer} do
      assert is_failure(fn ->
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "div(2, 0)"])
      end) =~ "Given the following expression: div(2, 0)"
    end
  end

  describe "node lifecycle management" do
    test "can stop node", %{node: peer} do
      use LanguageExtensions.While

      assert is_success(fn ->
        Control.main(["stop", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}"])
        while Node.ping(peer) != :pang do
          :timer.sleep(500)
        after
          10_000 ->
            raise "Expected #{peer} to stop after 10s!"
        end
        assert :pang = Node.ping(peer)
        :ok
      end) =~ "ok\n"
    end

    test "can restart node", %{table: tab} do
      use LanguageExtensions.While
      

      assert is_success(:ctrl_app, [table: tab, slave: false], fn peer ->
        :ok = :net_kernel.monitor_nodes(true)
        pid = :rpc.call(peer, GenServer, :whereis, [CtrlApp.Worker])
        assert is_pid(pid)
        ref = Process.monitor(pid)
        Control.main(["restart", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}"])
        while state = :restarting, state != :ok do
          :restarting ->
            receive do
              {:nodedown, ^peer} ->
                Process.demonitor(ref, [:flush])
                :down
              {:DOWN, ^ref, _type, ^pid, _reason} ->
                :restarting
            after
              5_000 ->
                raise "Expected #{peer} to go down during restart"
            end

          :down ->
            receive do
              {:nodeup, ^peer} ->
                :ok = :net_kernel.monitor_nodes(false)
                :restarted
            after
              1_000 ->
                 Node.ping(peer)
                 :down
            end

          :restarted ->
            if is_pid(:rpc.call(peer, GenServer, :whereis, [CtrlApp.Worker])) do
              :ok
            else
              IO.puts "Waiting for CtrlApp.Worker.."
              :restarted
            end
        after
          30_000 ->
            raise "Timed out waiting for #{peer} to restart!"
        end
      end)
    end

    test "can reboot node", %{table: tab} do
      use LanguageExtensions.While

      assert is_success(:ctrl_app, [table: tab, heart: true], fn peer ->
        # Watch for the node going down
        :erlang.monitor_node(peer, true)
        # Get the pid of a worker running in the app on the peer node and monitor it
        pid = :rpc.call(peer, GenServer, :whereis, [CtrlApp.Worker])
        assert is_pid(pid)
        ref = Process.monitor(pid)
        # Issue the reboot command
        Control.main(["reboot", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}"])
        # This is a little state machine which will loop until
        # the final state of `:ok` is reached, it starts with rebooting since we
        # have already issued the command
        while state = :rebooting, state != :ok do
          :rebooting ->
            # In this state, we're expecting both a DOWN and a :nodedown message
            # If we get the :nodedown first, we just flush the DOWN message, and proceed
            # to the :down state, otherwise we loop again until we get :nodedown
            # After 5s, we raise if we haven't seen the node die yet
            receive do
              {:nodedown, ^peer} ->
                Process.demonitor(ref, [:flush])
                :down
              {:DOWN, ^ref, _type, ^pid, _reason} ->
                :rebooting
            after
              5_000 ->
                raise "Expected #{peer} to stop when asked to reboot"
            end

          :down ->
            # In this state, the node is down and should be rebooting, we monitor all node up/down
            # events, and when we get nodeup for the peer, we know it has been restarted and can move
            # to the :rebooted state, otherwise we raise after 10s if the node hasn't come back up
            :ok = :net_kernel.monitor_nodes(true)
            receive do
              {:nodeup, ^peer} ->
                :ok = :net_kernel.monitor_nodes(false)
                :rebooted
            after
              10_000 ->
                raise "Expected #{peer} to restart when asked to reboot"
            end

          :rebooted ->
            # In this final state, we loop until we see that the worker has started back up
            # again, indicating that we've fully rebooted the node
            if is_pid(:rpc.call(peer, GenServer, :whereis, [CtrlApp.Worker])) do
              :ok
            else
              :rebooted
            end

        # If it takes 30s or longer to reboot successfully, raise an error and fail
        after
          30_000 ->
            raise "Timed out waiting for CtrlApp.Worker to come back up"
        end
      end)
    end
  end

  describe "reload_config" do
    test "with no changes to apply succeeds", %{node: peer} do
      assert is_success(fn ->
        Control.main(["reload_config", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}"])
      end) =~ "Config changes applied successfully!"
    end

    test "with a simple config is applied successfully", %{node: peer} do
      output = is_success(fn ->
        path = Path.join([__DIR__, "support", "simple.sys.config"])
        Control.main(["reload_config", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}", "--sysconfig", path])
      end)
      assert output =~ "Config changes applied successfully!"
      assert output =~ "Hi from simple.config.exs!"
    end
  end

  test "can get process info", %{node: peer} do
    output = is_success(fn -> 
      Control.main(["info", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}", "processes"])
    end)
    # The application_master is always running, so check for it in the list of processes
    assert output =~ ~r/^\s*application_master.start_it\/4\s+|\s+#PID<\d+\.\d+\.\d+>\s+|\s+application_master.loop_it\/4\s+|
\s+\d+\s+|\s+\d+\s+|\s+\d+\s+$/
  end

  defp is_failure(fun) do
    capture_io(:stderr, fn ->
      try do
        fun.()
      catch
        :exit, {:halt, _} ->
          :ok
      end
    end)
  end

  defp is_success(fun) do
    capture_io(fn ->
      try do
        fun.()
      catch
        :exit, {:halt, _} ->
          :ok
      end
    end)
  end

  defp is_success(app, opts, fun) when is_list(opts) do
    use LanguageExtensions.While
    

    use_heart? = Keyword.get(opts, :heart, false)
    use_slave? = Keyword.get(opts, :slave, false)
    tab = Keyword.fetch!(opts, :table)
    id = :ets.update_counter(tab, :counter, 1)
    # Get path for app's beam files
    project_path = Path.join([__DIR__, "fixtures", "#{app}"])
    ebin_path = Path.join([project_path, "_build", "dev", "lib", "#{app}", "ebin"])
    # Compile app
    {_, 0} = System.cmd "mix", ["compile"], env: [{"MIX_ENV", "dev"}], cd: project_path
    # Construct the code path for the slave node
    code_path = [String.to_charlist(ebin_path) | :code.get_path()]
    code_path_str =
      code_path
      |> Enum.map(&List.to_string/1)
      |> Enum.join(" ")
    
    apps = [:kernel, :stdlib, :compiler, :runtime_tools, :elixir, :logger, :distillery]
    profile = %Mix.Releases.Profile{include_erts: false}
    apps = Mix.Releases.Utils.get_apps(%Mix.Releases.Release{name: app, applications: apps, profile: profile})
    app_rel = {:release,
      {'#{app}', '0.1.0'},
      {:erts, '#{Mix.Releases.Utils.erts_version()}'},
      Enum.map(apps, fn %{name: n, vsn: v} -> {n, v} end) ++ [{app, '0.1.0'}]
    }
    rel_path = Path.join([project_path, "#{app}.rel"])
    :ok = Mix.Releases.Utils.write_term(rel_path, app_rel)
    old_cwd = File.cwd!
    File.cd!(project_path)
    {:ok, _, _} = :systools.make_script('#{app}', [
          {:path, [String.to_charlist(Path.join([project_path, "_build", "dev", "lib", "*", "ebin"]))]}, 
          :local, 
          :silent, 
          :warnings_as_errors, 
          :no_dot_erlang, 
          :no_warn_sasl
    ])
    File.cd!(old_cwd)
    boot_path = Path.join([project_path, "#{app}"])

    # If we're not using heart for this test, just use the :slave module directly,
    # otherwise, we have to start up the node manually because we have to pass some
    # extra flags to make sure that heart is configured correctly. For some tests,
    # being started as a slave changes behavior (restart), so we also have an option
    # to start a completely standalone node which will be managed outside of the test
    name =
      cond do
        not use_heart? and use_slave? ->
          # Start slave node for app
          {:ok, name} = :slave.start('127.0.0.1', :"#{app}#{id}", inet_loader_args() ++ ' -boot #{boot_path}')
          name

        not use_heart? ->
          # Start a local node, but not as a slave, we'll have to clean up the process manually
          {_, 0} = System.cmd "erl", [
            "-noshell",
            "-noinput",
            "-detached",
            "-boot", "#{app}",
            "-name", "#{app}#{id}@127.0.0.1",
            "-setcookie", "#{Node.get_cookie}",
            "-pa" | Enum.map(code_path, &List.to_string/1)
          ], cd: project_path
          # We know the name
          :"#{app}#{id}@127.0.0.1"

        :else ->
          heart_cmd = "erl -detached " <>
            "-boot #{app} " <>
            "-master test_cli@127.0.0.1 -s slave slave_start test_cli@127.0.0.1 slave_waiter_0 " <>
            "-name #{app}#{id}@127.0.0.1 -setcookie #{Node.get_cookie} " <>
            "-pa #{code_path_str} " #<>
            #"-eval 'application:ensure_all_started(#{app}).'"
          {_, 0} = System.cmd "erl", [
            "-detached",
            "-boot", "#{app}",
            "-master", "test_cli@127.0.0.1",
            "-s", "slave", "slave_start", "test_cli@127.0.0.1", "slave_waiter_0",
            "-name", "#{app}#{id}@127.0.0.1",
            "-setcookie", "#{Node.get_cookie}",
            "-heart",
            "-env", "HEART_COMMAND", heart_cmd,
            "-env", "HEART_BEAT_TIMEOUT", "2",
            "-pa" | Enum.map(code_path, &List.to_string/1)
          ], cd: project_path
          # We know the name
          :"#{app}#{id}@127.0.0.1"
      end

    # Wait for node
    while Node.ping(name) != :pong do
      :timer.sleep(500)
    after
      10_000 ->
        raise "Could not start #{name} after 10s, something is probably wrong.."
    end

    if not use_heart? and not use_slave? do
      # Get the pid of the remote, and store it in process dict for cleanup
      pid = :rpc.call(name, :os, :getpid, [])
      Process.put(name, pid)
    end
    
    # We're good to go!
    # Run test
    try do
      if is_nil(System.get_env("VERBOSE_TESTS")) do
        assert capture_io(fn ->
          :ok = fun.(name)
        end)
      else
        :ok = fun.(name)
      end
    after
      case Process.get(name) do
        nil ->
          # No need to do anything, it is a slave node
          :ok
        {:badrpc, _} ->
          # Call to get pid failed, try to make one more to kill the node just in case
          _ = :rpc.call(name, :erlang, :halt, [])
        pid ->
          # Try rpc first
          case :rpc.call(name, :init, :stop, []) do
            {:badrpc, reason} ->
              IO.inspect "Unable to stop node: #{inspect reason}, attempting to kill.."
              # Kill it with fire
              _ = System.cmd("kill", ["-s", "KILL", "#{pid}"])
            _ ->
              # Success
              :ok
          end
      end
    end
  end

  @doc """
  Sets up the current node as the boot server.
  """
  def start_boot_server(node) do
    case :net_kernel.start([node]) do
      {:ok, _} ->
        Node.set_cookie(:cli_test)
        # Allow spawned nodes to fetch all code from this node
        IO.puts "Starting boot server.."
        {:ok, _} = :erl_boot_server.start([{127,0,0,1}])
        IO.puts "Started boot server."
        :ok
      {:error, _} ->
        raise "make sure epmd is running before starting the test suite. " <>
          "Running `epmd -daemon` once is usually enough."
    end
  end

  @doc """
  Spawns the given nodes.
  """
  def spawn_nodes(children) do
    children
    |> Enum.map(&Task.async(fn -> spawn_node(&1) end))
    |> Enum.map(&Task.await(&1, 30_000))
  end

  defp spawn_node(node_host) do
    {:ok, name} = :slave.start('127.0.0.1', node_name(node_host), inet_loader_args())
    :rpc.call(name, :code, :add_paths, [:code.get_path()])
    {:ok, _} = :rpc.call(name, :application, :ensure_all_started, [:elixir])
    {:ok, _} = :rpc.call(name, :application, :ensure_all_started, [:distillery])
    :timer.sleep(1_000)
  end

  defp inet_loader_args(extra \\ []) when is_list(extra) do
    base = "-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()}"
    args = Enum.reduce(extra, base, fn arg, acc ->
      a = String.to_charlist(arg)
      acc <> " #{a}"
    end)
    String.to_charlist(args)
  end

  defp node_name(node_host) do
    node_host
    |> to_string
    |> String.split("@")
    |> Enum.at(0)
    |> String.to_atom
  end
end
