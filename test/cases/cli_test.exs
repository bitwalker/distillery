defmodule Distillery.Test.CliTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Distillery.Releases.Runtime.Control
  alias ExUnit.ClusteredCase.Node, as: NodeManager
  
  @fixtures_path Path.join([__DIR__, "..", "fixtures"])

  setup_all do
    :rand.seed(:exs64)
    Node.start(:"primary@127.0.0.1", :longnames)
    Application.ensure_all_started(:ex_unit_clustered_case)
    Application.put_env(:artificery, :no_halt, true)
  end
  
  setup do
    {:ok, pid} = NodeManager.start_nolink([
      boot_timeout: 30_000, 
      post_start_functions: [{Application, :ensure_all_started, [:distillery]}],
      stdout: :standard_error
    ])
    on_exit fn -> 
      if Process.alive?(pid) do
        NodeManager.kill(pid)
      end
    end
    peer = NodeManager.name(pid)
    %{node: peer}
  end

  describe "when pinging a node" do
    test "prints pong when available", %{node: peer} do
      assert is_success(fn ->
        Control.main(["--verbose", "ping", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}"])
      end) == "pong\n"
    end

    test "prints friendly error (and pang) when unavailable" do
      assert is_failure(fn ->
        Control.main(["--verbose", "ping", "--cookie", "#{Node.get_cookie}", "--name", "missingno@127.0.0.1"])
      end) =~ "Received 'pang' from missingno@127.0.0.1!\n"
    end

    test "omitting required flag produces friendly error", %{node: peer} do
      assert is_failure(fn ->
        Control.main(["--verbose", "ping", "--name", "#{peer}"])
      end) =~ "Missing required flag '--cookie'."
    end
  end

  describe "rpc/eval" do
    test "eval is executed locally" do
      assert is_success(fn ->
        Control.main(["eval", "IO.puts \"Hello from \" <> to_string(Node.self) <> \"!\""])
      end) =~ "Hello from primary@127.0.0.1!"
    end

    test "eval --mfa --argv" do
      assert is_success(fn ->
        Control.main(["eval", "--mfa", "IO.inspect/1", "--argv", "--", "foo", "bar"])
      end) =~ "[\"foo\", \"bar\"]"
    end

    test "eval --mfa correct args" do
      assert is_success(fn ->
        Control.main(["eval", "--mfa", "Distillery.Test.Tasks.run/2", "--", "foo", "bar"])
      end) =~ "[arg1: \"foo\", arg2: \"bar\"]"
    end

    test "eval --mfa incorrect args" do
      assert is_failure(fn ->
        Control.main(["eval", "--mfa", "Distillery.Test.Tasks.run/2", "--", "foo", "bar", "baz"])
      end) =~ "function has a different arity!"
    end

    test "eval --file" do
      assert is_success(fn ->
        Control.main(["eval", "--file", Path.join([@fixtures_path, "files", "eval_file_example.exs"]) |> Path.expand])
      end) =~ "ok from primary@127.0.0.1\n"
    end

    test "eval syntax error produces friendly error" do
      assert is_failure(fn ->
        Control.main(["eval", "div(2, 0)"])
      end) =~ "Evaluation failed with: bad argument in arithmetic expression"
    end

    test "rpc is executed remotely", %{node: peer} do
      assert is_success(fn ->
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "IO.puts \"Hello from \" <> to_string(Node.self) <> \"!\""])
      end) =~ ~r/Hello from #{peer}!/
    end

    test "rpc --file", %{node: peer} do
      assert is_success(fn ->
        path = Path.join([@fixtures_path, "files", "eval_file_example.exs"]) |> Path.expand
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "--file", path])
      end) =~ ~r/ok from #{peer}\n/
    end

    test "rpc --mfa --argv", %{node: peer} do
      assert is_success(fn ->
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "--mfa", "IO.inspect/1", "--argv", "--", "foo", "bar"])
      end) =~ "[\"foo\", \"bar\"]"
    end

    test "rpc --mfa correct args", %{node: peer} do
      assert is_success(fn ->
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "--mfa", "Distillery.Test.Tasks.run/2", "--", "foo", "bar"])
      end) =~ "[arg1: \"foo\", arg2: \"bar\"]"
    end

    test "rpc --mfa incorrect args", %{node: peer} do
      assert is_failure(fn ->
        Control.main(["rpc", "--cookie", "#{Node.get_cookie}", "--name", "#{peer}", "--mfa", "Distillery.Test.Tasks.run/2", "--", "foo", "bar", "baz"])
      end) =~ "function has a different arity!"
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

    test "can restart node" do
      use LanguageExtensions.While
      

      assert is_success(:ctrl_app, [], fn peer ->
        :ok = :net_kernel.monitor_nodes(true, [:nodedown_reason, {:node_type, :all}])
        while not is_pid(:rpc.call(peer, GenServer, :whereis, [CtrlApp.Worker])) do
          :timer.sleep(500)
        after
          10_000 ->
            raise "Expected #{peer} to start CtrlApp.Worker within 10s"
        end
        pid = :rpc.call(peer, GenServer, :whereis, [CtrlApp.Worker])
        assert is_pid(pid)
        ref = Process.monitor(pid)
        Control.main(["restart", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}"])
        while state = :restarting, state != :ok do
          :restarting ->
            receive do
              {:nodedown, ^peer, _} ->
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
              {:nodeup, ^peer, _} ->
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
              :restarted
            end
        after
          30_000 ->
            raise "Timed out waiting for #{peer} to restart!"
        end
      end)
    end

    test "can reboot node" do
      use LanguageExtensions.While

      assert is_success(:ctrl_app, [heart: true], fn peer ->
        # Watch for the node going down
        :erlang.monitor_node(peer, true)
        :net_kernel.monitor_nodes(true, [node_type: :all])
        # Get the pid of a worker running in the app on the peer node and monitor it
        while not is_pid(:rpc.call(peer, GenServer, :whereis, [CtrlApp.Worker])) do
          :timer.sleep(500)
        after
          10_000 ->
            raise "Expected #{peer} to start CtrlApp.Worker, but hasn't happened after 10s"
        end
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
              {:nodedown, ^peer, _} ->
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
              {:nodeup, ^peer, _} ->
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
      is_success(fn ->
        assert :undefined = :rpc.call(peer, :application, :get_env, [:distillery, :simple])
        path = Path.join([@fixtures_path, "files", "simple.sys.config"])
        Control.main(["reload_config", "--name", "#{peer}", "--cookie", "#{Node.get_cookie}", "--sysconfig", path])
        assert {:ok, :success} = :rpc.call(peer, :application, :get_env, [:distillery, :simple])
      end)
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
    capture_io(fn ->
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
    # Get path for app's beam files
    project_path = Path.join([@fixtures_path, "#{app}"])
    ebin_path = Path.join([project_path, "_build", "dev", "lib", "#{app}", "ebin"])
    # Compile app
    {_, 0} = System.cmd "mix", ["compile"], env: [{"MIX_ENV", "dev"}], cd: project_path
    # Add the extra code path for the slave node
    args = ["-pa", ebin_path]
    post_start_funs = [
      {Application, :ensure_all_started, [:distillery]},
      {Application, :ensure_all_started, [app]}
    ]
    # Start the node
    {:ok, pid} = NodeManager.start_nolink([
      boot_timeout: 30_000, 
      erl_flags: args, 
      post_start_functions: post_start_funs, 
      heart: use_heart?,
      stdout: :standard_error
    ])
    on_exit fn -> 
      if Process.alive?(pid) do
        NodeManager.kill(pid)
      end
    end
    # Get the node name
    name = NodeManager.name(pid)

    if is_nil(System.get_env("VERBOSE_TESTS")) do
      assert capture_io(fn ->
        :ok = fun.(name)
      end)
    else
      :ok = fun.(name)
    end
  end
end
