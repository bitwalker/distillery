defmodule Mix.Releases.Runtime.CLI do
  @moduledoc false

  defmodule Log do
    @moduledoc "A minimal logger"

    def init do
      # For logger state
      :ets.new(__MODULE__, [:public, :set, :named_table])
    end

    def configure(%{verbosity: verbosity} = opts) do
      :ets.insert(__MODULE__, {:level, verbosity})
      opts
    end

    def configure(opts), do: opts

    def debug(msg), do: log(:debug, colorize("==> #{msg}", IO.ANSI.cyan()))
    def info(msg), do: log(:info, msg)
    def success(msg), do: log(:warn, colorize(msg, IO.ANSI.bright() <> IO.ANSI.green()))
    def warn(msg), do: log(:warn, colorize(msg, IO.ANSI.yellow()))

    def error(msg) do
      log(:error, colorize(msg, IO.ANSI.red()))
      System.halt(1)
    end

    defp log(level, msg), do: log(level, get_verbosity(), msg)
    defp log(_, :debug, msg), do: IO.puts(msg)
    defp log(:debug, :info, _msg), do: :ok
    defp log(_, _, msg), do: IO.puts(msg)

    defp colorize(msg, color), do: IO.ANSI.format([color, msg, IO.ANSI.reset()])

    defp get_verbosity(), do: get_verbosity(:ets.lookup(__MODULE__, :level))
    defp get_verbosity([]), do: :info
    defp get_verbosity([{_, v}]), do: v
  end

  @doc """
  Main entry point for this script.

  Handles parsing and validating arguments, then dispatching the selected command
  """
  def main() do
    Log.init()

    args =
      :init.get_plain_arguments()
      |> Enum.map(&List.to_string/1)
      |> Enum.drop_while(fn
        "--" -> false
        _ -> true
      end)
      |> Enum.drop(1)

    args
    |> parse_args()
    |> Log.configure()
    |> dispatch()

    System.halt(0)
  end

  ## Commands

  @doc """
  Prints help for this tool
  """
  def help([], _opts) do
    IO.puts("""
    cli.exs - A release utility tool
    -------
    usage: elixir -r cli.exs -e "#{__MODULE__}.main" -- [options] <command> [command options]

    Options:
    --name=<name>:     Set the name of the target node to connect to,
                       can either be in long form (i.e. 'foo@bar') or
                       short form (i.e. 'foo')
    --cookie=<cookie>: Set the secret cookie used when connecting to other nodes
    --verbose:         Turn on verbose output (you can use -v for normal or -vv for debug)
    """)

    System.halt(1)
  end

  def help([command | _], opts) do
    case command do
      "ping" ->
        IO.puts("""
        Pings the remote node.
        """)

      "stop" ->
        IO.puts("""
        Stops the remote node.
        """)

      "restart" ->
        IO.puts("""
        Restarts the remote node. This will not restart the emulator.
        """)

      "reboot" ->
        IO.puts("""
        Reboots the remote node. This will restart the emulator.
        """)

      "reload_config" ->
        IO.puts("""
        Reloads the config of the remote node after modifications have been made.
        """)

      "rpc" ->
        IO.puts("""
        Executes `:rpc.call/4` against the remote node.

        You can provide a module/function, or module/function/args expression:

            rpc "MyModule.function"
            rpc "MyModule.function([foo: :bar])"

        The provided expression will be parsed into the appropriate call against the remote node.
        """)

      "eval" ->
        IO.puts("""
        Executes the provided expression locally and writes the result to stdout.

        Like `rpc`, you can provide an expression, but this time it can be any arbitrary expression.

            eval "foo = 1 + 1; IO.inspect(foo)"
            #=> 2
        """)

      _ ->
        IO.puts("Unrecognized command '#{command}'\n")
        help([], opts)
    end

    System.halt(1)
  end

  @doc """
  Pings a remote node.
  """
  def ping(_args, %{remote: remote}) do
    case hidden_connect(remote) do
      {:ok, :pong} ->
        Log.info("pong")

      {:error, :pang} ->
        failed_connect!(remote)
    end
  end

  def ping(_args, _opts), do: missing_dist_opts!()

  @doc """
  Stops a remote node
  """
  def stop(_args, %{remote: remote}) do
    hidden_connect!(remote)
    _ = :rpc.call(remote, :init, :stop, [], 60_000)
    Log.info("ok")
  end

  def stop(_args, _opts), do: missing_dist_opts!()

  @doc """
  Restarts a remote node (this is a soft restart, emulator is left up)
  """
  def restart(_args, %{remote: remote}) do
    hidden_connect!(remote)
    _ = :rpc.call(remote, :init, :restart, [], 60_000)
    Log.info("ok")
  end

  def restart(_args, _opts), do: missing_dist_opts!()

  @doc """
  Reboots a remote node (this is a hard restart, emulator is restarted)
  """
  def reboot(_args, %{remote: remote}) do
    hidden_connect!(remote)
    _ = :rpc.call(remote, :init, :reboot, [], 60_000)
    Log.info("ok")
  end

  def reboot(_args, _opts), do: missing_dist_opts!()

  @doc """
  Applies any pending configuration changes in config files to a remote node.
  """
  def reload_config(args, %{remote: remote}) do
    opts = [
      switches: [
        sysconfig: :string
      ]
    ]

    {flags, _, _} = OptionParser.parse(args, opts)

    sysconfig =
      case Keyword.get(flags, :sysconfig) do
        nil ->
          []

        path ->
          case :file.consult(String.to_charlist(path)) do
            {:error, reason} ->
              Log.error("Unable to read sys.config from #{path}: #{inspect(reason)}")

            {:ok, [config]} ->
              config
          end
      end

    case rpc(remote, :application_controller, :prep_config_change) do
      {:badrpc, reason} ->
        Log.error("Unable to prepare config change, call failed: #{inspect(reason)}")

      oldenv ->
        Log.info("Applying sys.config...")

        for {app, config} <- sysconfig do
          Log.debug("Updating #{app}..")

          for {key, value} <- config do
            Log.debug("  #{app}.#{key} = #{inspect(value)}")

            case rpc(remote, :application, :set_env, [app, key, value, [persistent: true]]) do
              {:badrpc, reason} ->
                Log.error("Failed during call to :application.set_env/4: #{inspect(reason)}")

              _ ->
                :ok
            end
          end
        end

        case Keyword.get(sysconfig, :distillery) do
          nil ->
            Log.debug("Skipping Mix.Config, no providers given!")

          opts ->
            providers = Keyword.get(opts, :config_providers, [])

            case rpc(remote, Mix.Releases.Config.Provider, :init, [providers], :infinity) do
              {:badrpc, reason} ->
                Log.error("Failed to run config providers: #{inspect(reason)}")

              _ ->
                Log.debug("Configuation changes applied to application env!")
            end
        end

        case rpc(remote, :application_controller, :config_change, [oldenv]) do
          {:badrpc, reason} ->
            Log.error("Failed during :application_controller.config_change/1: #{inspect(reason)}")

          _ ->
            Log.success("Config changes applied successfully!")
        end
    end
  end

  def reload_config(_args, _opts), do: missing_dist_opts!()

  @doc """
  Executes an expression on the remote node.
  """
  def rpc([expr | _], %{remote: remote}) do
    case Code.string_to_quoted(expr) do
      {:ok, quoted} ->
        case rpc(remote, Code, :eval_quoted, [quoted], :infinity) do
          {:badrpc, reason} ->
            Log.error("Remote call failed with: #{inspect(reason)}")

          {result, _bindings} ->
            IO.inspect(result)
        end

      {:error, {_line, error, token}} when is_binary(error) and is_binary(token) ->
        Log.error("Invalid expression: #{error <> token}")

      {:error, {_line, error, _}} ->
        Log.error("Invalid expression: #{inspect(error)}")
    end
  end

  def rpc([], %{remote: _}) do
    Log.error("You must provide an Elixir expression to 'rpc'")
  end

  def rpc(_, _), do: missing_dist_opts!()

  @doc """
  Executes an expression on the local node.
  """
  def eval([expr | _], _opts) do
    case Code.string_to_quoted(expr) do
      {:ok, quoted} ->
        try do
          Code.eval_quoted(quoted)
        rescue
          err ->
            Log.error("Evaluation failed with: " <> Exception.message(err))
        end

      {:error, {_line, error, token}} when is_binary(error) and is_binary(token) ->
        Log.error("Invalid expression: #{error <> token}")

      {:error, {_line, error, _}} ->
        Log.error("Invalid expression: #{inspect(error)}")
    end
  end

  def eval([], _opts) do
    Log.error("You must provide an Elixir expression to 'eval'")
  end

  @doc """
  Unpacks a release in preparation for it to be loaded
  """
  # TODO: Should match on remote, name, and cookie for all relevant handlers
  def unpack_release(args, %{remote: remote}) do
    opts = [strict: [release: :string, version: :string]]
    {flags, _, _} = OptionParser.parse(args, opts)
    release = Keyword.get(flags, :release)
    version = Keyword.get(flags, :version)

    unless is_binary(release) and is_binary(version) do
      Log.error("You must provide both --release and --version to 'unpack_release'")
    end

    releases = which_releases(release, remote)

    case List.keyfind(releases, version, 0) do
      nil ->
        # Not installed, so unpack tarball
        Log.info(
          "Release #{release}:#{version} not found, attempting to unpack releases/#{version}/#{
            release
          }.tar.gz"
        )

        package = version |> Path.join(release) |> String.to_charlist()

        case rpc(remote, :release_handler, :unpack_release, [package], :infinity) do
          {:badrpc, reason} ->
            Log.error("Unable to unpack release, call failed with: #{inspect(reason)}")

          {:ok, vsn} ->
            Log.success("Unpacked #{inspect(vsn)} successfully!")

          {:error, reason} ->
            Log.warn("Installed versions:")

            for {version, status} <- releases do
              Log.warn("  * #{version}\t#{status}")
            end

            Log.error("Unpack failed with: #{inspect(reason)}")
        end

      {_ver, reason} when reason in [:old, :unpacked, :current, :permanent] ->
        # Already unpacked
        Log.warn("Release #{release}:#{version} is already unpacked!")
    end
  end

  def unpack_release(_, _), do: missing_dist_opts!()

  @doc """
  Installs a release, unpacking if necessary
  """
  def install_release(args, %{remote: remote}) do
    opts = [strict: [release: :string, version: :string]]
    {flags, _, _} = OptionParser.parse(args, opts)
    release = Keyword.get(flags, :release)
    version = Keyword.get(flags, :version)

    unless is_binary(release) and is_binary(version) do
      Log.error("You must provide both --release and --version to 'install_release'")
    end

    releases = which_releases(release, remote)

    case List.keyfind(releases, version, 0) do
      nil ->
        # Not installed, so unpack tarball
        Log.info(
          "Release #{release}:#{version} not found, attempting to unpack releases/#{version}/#{
            release
          }.tar.gz"
        )

        package = Path.join(version, release)

        case rpc(remote, :release_handler, :unpack_release, [package], :infinity) do
          {:badrpc, reason} ->
            Log.error("Failed during remote call with: #{inspect(reason)}")

          {:ok, _} ->
            Log.info("Unpacked #{version} successfully!")
            install_and_permafy(remote, release, version)

          {:error, reason} ->
            Log.warn("Installed versions:")

            for {vsn, status} <- releases do
              Log.warn("  * #{vsn}\t#{status}")
            end

            Log.error("Unpack failed with: #{inspect(reason)}")
        end

      {_ver, :old} ->
        Log.info("Release #{release}:#{version} is marked old, switching to it..")
        install_and_permafy(remote, release, version)

      {_ver, :unpacked} ->
        Log.info("Release #{release}:#{version} is already unpacked, installing..")
        install_and_permafy(remote, release, version)

      {_ver, :current} ->
        Log.info(
          "Release #{release}:#{version} is already installed and current, making permanent.."
        )

        permafy(remote, release, version)

      {_ver, :permanent} ->
        Log.info("Release #{release}:#{version} is already installed, current, and permanent!")
    end
  end

  def install_release(_, _), do: missing_dist_opts!()

  @doc """
  Prints code paths to stdout for easy access in shell
  """
  def get_code_paths(args, _opts) do
    opts = [
      strict: [
        root_dir: :string,
        erts_dir: :string,
        release: :string,
        version: :string
      ]
    ]

    {flags, _, _} = OptionParser.parse(args, opts)

    release = Keyword.get(flags, :release)
    version = Keyword.get(flags, :version)

    unless is_binary(release) and is_binary(version) do
      Log.error("You must pass --release and --version to 'get_code_paths'")
    end

    case select_release(release, version, flags) do
      {:ok, {:release, _, _, _, libs, _}} ->
        for {_name, _ver, dir} <- libs do
          IO.write("-pa #{dir}/ebin ")
        end

      {:error, :no_such_release} ->
        Log.error("Unable to find release #{release}:#{version}!")
    end
  end

  ## Option parsing, validation and dispatch

  defp dispatch(%{command: command, args: args} = opts) do
    apply(__MODULE__, command, [args, opts])
  end

  defp parse_args(args) do
    opts = [
      aliases: [v: :verbose],
      strict: [
        name: :string,
        cookie: :string,
        remote: :string,
        verbose: :count
      ]
    ]

    args
    |> OptionParser.parse_head(opts)
    |> parse_opts()
  end

  defp parse_opts({_known, [], _invalid}) do
    %{command: :help, args: []}
  end

  defp parse_opts({known_opts, [command | args], _invalid}) do
    command = String.to_atom(command)
    parse_opts(known_opts, %{command: command, args: args})
  end

  defp parse_opts([], opts), do: opts

  defp parse_opts([{:verbose, level} | rest], opts) do
    verbosity =
      case level do
        1 -> :info
        _ -> :debug
      end

    parse_opts(rest, Map.put(opts, :verbosity, verbosity))
  end

  defp parse_opts([{:cookie, cookie} | rest], opts) do
    cookie = String.to_atom(cookie)

    if Node.alive?() do
      Node.set_cookie(cookie)
    end

    parse_opts(rest, Map.put(opts, :cookie, cookie))
  end

  defp parse_opts([{:name, name} | rest], opts) do
    dist_opts =
      case Regex.split(~r/@/, name) do
        [sname] ->
          {String.to_atom(sname), String.to_atom("#{sname}_maint_"), :shortnames}

        [sname, host] ->
          {String.to_atom("#{sname}@#{host}"), String.to_atom("#{sname}_maint_@#{host}"),
           :longnames}

        _parts ->
          {:error, {:invalid_opts, :name, "invalid name: #{name}"}}
      end

    case dist_opts do
      {:error, _} = err ->
        err

      {remote, name, type} ->
        start_epmd()

        case :net_kernel.start([name, type]) do
          {:ok, _} ->
            case Map.get(opts, :cookie) do
              nil ->
                :ok

              cookie ->
                # We need to set the cookie now that the node is started
                Node.set_cookie(cookie)
            end

            parse_opts(rest, opts |> Map.put(:name, name) |> Map.put(:remote, remote))

          {:error, reason} ->
            {:error, "Could not start distribution: #{inspect(reason)}"}
        end
    end
  end

  ## Helpers

  defp rpc(remote, m, f, a \\ [], timeout \\ 60_000) do
    :rpc.call(remote, m, f, a, timeout)
  end

  defp missing_dist_opts! do
    Log.error("This command requires --name and --cookie to be provided")
  end

  defp failed_connect!(remote) do
    Log.error(
      "Received 'pang' from #{remote}. " <>
        "Possible reasons for this include:\n" <>
        "  - The cookie is mismatched between us and the target node\n" <>
        "  - We cannot establish a remote connection to the node\n" <> System.halt(1)
    )
  end

  defp hidden_connect!(target) do
    case hidden_connect(target) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        failed_connect!(target)
    end
  end

  defp hidden_connect(target) do
    case :net_kernel.hidden_connect_node(target) do
      true ->
        case :net_adm.ping(target) do
          :pong ->
            {:ok, :pong}

          :pang ->
            {:error, :pang}
        end

      _ ->
        {:error, :pang}
    end
  end

  defp start_epmd() do
    System.cmd(epmd(), ["-daemon"])
    :ok
  end

  defp epmd() do
    case System.find_executable("epmd") do
      nil ->
        Log.error("Unable to locate epmd!")

      path ->
        path
    end
  end

  defp install_and_permafy(remote, release, version) do
    vsn = String.to_charlist(version)

    case rpc(remote, :release_handler, :check_install_release, [vsn], :infinity) do
      {:badrpc, reason} ->
        Log.error("Failed during remote call with: #{inspect(reason)}")

      {:ok, _other_vsn, _desc} ->
        :ok

      {:error, reason} ->
        Log.error(
          "Release handler check for #{release}:#{version} failed with: #{inspect(reason)}"
        )
    end

    case rpc(remote, :release_handler, :install_release, [vsn, [update_paths: true]], :infinity) do
      {:badrpc, reason} ->
        Log.error("Failed during remote call with: #{inspect(reason)}")

      {:ok, _, _} ->
        Log.info("Installed release #{release}:#{version}")
        update_config(remote)
        permafy(remote, release, version)
        :ok

      {:error, {:no_such_release, ^vsn}} ->
        Log.warn("Installed versions:")

        for {vsn, status} <- which_releases(release, remote) do
          Log.warn("  * #{vsn}\t#{status}")
        end

        Log.error("Unable to revert to #{version}: not installed")

      {:error, {:old_processes, mod}} ->
        # As described in http://erlang.org/doc/man/appup.html
        # When executing a relup containing soft_purge instructions:
        #   If the value is soft_purge, release_handler:install_release/1
        #   returns {:error, {:old_processes, mod}}
        Log.error("Unable to install #{version}: old processes still running code from #{mod}")

      {:error, reason} ->
        Log.error("Release handler failed to install: #{inspect(reason)}")
    end
  end

  defp permafy(remote, release, version) do
    case rpc(remote, :release_handler, :make_permanent, [String.to_charlist(version)], :infinity) do
      {:badrpc, reason} ->
        Log.error("Failed during remote call with: #{inspect(reason)}")

      :ok ->
        File.cp(Path.join("bin", "#{release}-#{version}"), Path.join("bin", release))
        Log.info("Made release #{release}:#{version} permanent")
    end
  end

  defp update_config(remote) do
    Log.info("Updating config..")

    with {:ok, providers} <-
           rpc(remote, :application, :get_env, [:distillery, :config_providers]),
         oldenv <- rpc(remote, :application_controller, :prep_config_change),
         _ <- rpc(remote, Mix.Releases.Config.Provider, :init, [providers], :infinity),
         _ <- rpc(remote, :application_controller, :config_change, [oldenv]) do
      :ok
    else
      {:badrpc, reason} ->
        Log.error("Failed during remote call with: #{inspect(reason)}")

      :undefined ->
        Log.info("No config providers, skipping config update")
        # No config providers
        :ok
    end
  end

  defp which_releases(name, remote) do
    case rpc(remote, :release_handler, :which_releases, [], :infinity) do
      {:badrpc, reason} ->
        Log.error("Failed to interrogate release information from #{remote}: #{inspect(reason)}")

      releases ->
        name = String.to_charlist(name)

        releases
        |> Enum.filter(fn {n, _, _, _} -> n == name end)
        |> Enum.map(fn {_, version, _, status} -> {List.to_string(version), status} end)
    end
  end

  # Finds a specific release in the RELEASES file
  defp select_release(release, version, opts) do
    root_dir = Keyword.get(opts, :root_dir)

    if is_nil(root_dir) do
      Log.error("Command is missing --root-dir flag")
    end

    erts_dir = Keyword.get(opts, :erts_dir)

    if is_nil(erts_dir) do
      Log.error("Command is missing --erts-dir flag")
    end

    releases = get_releases(root_dir, erts_dir)
    do_select_releases(releases, String.to_charlist(release), String.to_charlist(version))
  end

  defp do_select_releases([], _release, _version) do
    {:error, :no_such_release}
  end

  defp do_select_releases([{:release, release, version, _, _, _} = rel | _], release, version) do
    {:ok, rel}
  end

  defp do_select_releases([_ | rest], release, version) do
    do_select_releases(rest, release, version)
  end

  # Parses the RELEASES file
  defp get_releases(root_dir, erts_dir) do
    releases_file = Path.join([root_dir, "releases", "RELEASES"])
    {:ok, [releases]} = :file.consult(String.to_charlist(releases_file))
    Enum.map(releases, &fix_release(&1, root_dir, erts_dir))
  end

  # Used to fix invalid paths in RELEASES
  defp fix_release(
         {:release, release, version, erts_vsn, libs, status} = rel,
         root_dir,
         erts_dir
       ) do
    current_erts_vsn = extract_erts_vsn(erts_dir)
    included? = is_erts_included(root_dir, erts_dir)
    is_current? = current_erts_vsn == erts_vsn

    cond do
      included? ->
        # If ERTS is included, we're good here
        rel

      is_current? ->
        # We're using the host ERTS, and it is a match for the release ERTS version
        # We just need to make sure the path is up to date
        fixed_libs =
          for {name, vsn, _dir} = lib <- libs do
            if is_erts_lib(erts_dir, name) do
              case get_erts_lib(erts_dir, name, vsn) do
                false ->
                  Log.error("Invalid RELEASES: Could not find #{name}:#{vsn} in #{erts_dir}")

                real_dir ->
                  {name, vsn, real_dir}
              end
            else
              lib
            end
          end

        {:release, release, version, erts_vsn, fixed_libs, status}

      :else ->
        # We didn't include ERTS, and the host version is not a match
        # for the release. We have to assume it will fail
        Log.error(
          "Invalid RELEASES file: The specified ERTS #{erts_vsn} does not match host #{
            current_erts_vsn
          }"
        )
    end
  end

  defp is_erts_included(root_dir, erts_dir) do
    # If erts_dir is relative to root_dir, it is included in release
    case Path.relative_to(erts_dir, root_dir) do
      ^erts_dir ->
        false

      _ ->
        true
    end
  end

  # Determines if the given app is an ERTS library
  defp is_erts_lib(erts_dir, name) do
    dir = Path.join([erts_dir, "..", "lib"])

    case Path.wildcard(Path.join(dir, "#{name}-*")) do
      [] ->
        false

      _ ->
        true
    end
  end

  # Returns the absolute path to an ERTS lib, or false if it doesn't exist
  defp get_erts_lib(erts_dir, name, vsn) do
    dir = Path.join([erts_dir, "..", "lib", "#{name}-#{vsn}"])

    if File.exists?(dir) do
      dir
    else
      false
    end
  end

  # Given a path to the ERTS directory, get the ERTS version
  defp extract_erts_vsn(erts_dir) do
    "erts-" <> vsn = Path.basename(erts_dir)
    String.to_charlist(vsn)
  end
end
