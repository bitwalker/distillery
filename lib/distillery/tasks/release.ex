defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Command line options

    * `--name`    - selects a specific release to build
    * `--env`     - selects a specific release environment to build with
    * `--profile` - selects both a release and environment, syntax for profiles is `name:env`

  Releases and environments are defined in `rel/config.exs`, created via
  `release.init`. When determining the name and environment to use, refer to the
  definitions in that file if you are not sure what options are available.

    * `--erl`     - provide extra flags to `erl` when running the release, expects a string
    * `--dev`     - this switch indicates whether to build the release in "dev mode", which
      symlinks build artifacts into the release rather than copying them, both significantly
      speeding up release builds, as well as making it possible to recompile the project and
      have the release pick up the changes without rebuilding the release.
    * `--silent`  - mutes all logging output
    * `--quiet`   - reduce logging output to essentials
    * `--verbose` - produce detailed output about release assembly
    * `--no-tar`  - skip packaging the release in a tarball after assembly
    * `--warnings-as-errors` - treat any release-time warnings as errors which fail the build
    * `--no-warn-missing`    - ignore any errors about missing applications

  ### Upgrades

  You can tell Distillery to build an upgrade with `--upgrade`.

  Upgrades require a source version and a target version (the current version).
  Distillery will automatically determine a source version by looking at previously
  built releases in the output directory, and selecting the most recent. If none
  are available, building the upgrade will fail. You can specify a specific version
  to upgrade from with `--upfrom`, which expects a version string. If the selected
  version cannot be found, the upgrade build will fail.

  ### Executables

  Distillery can build pseudo-executable files as an artifact, rather than plain
  tarballs. These executables are not true executables, but rather self-extracting
  TAR archives, which handle extraction and passing any command-line arguments to
  the appropriate shell scripts in the release. The following flags are used for
  these executables:

    * `--executable`  - tells Distillery to produce a self-extracting archive
    * `--transient`   - tells Distillery to produce a self-extracting archive which
      will remove the extracted contents from disk after execution

  ## Usage

  You are generally recommended to use `rel/config.exs` to configure Distillery, and
  simply run `mix release` with `MIX_ENV` set to the Mix environment you are targeting.
  The following are some usage examples:

      # Builds a release with MIX_ENV=dev (the default)
      mix release

      # Builds a release with MIX_ENV=prod
      MIX_ENV=prod mix release

      # Builds a release for a specific release environment
      MIX_ENV=prod mix release --env=dev

  The default configuration produced by `release.init` will result in `mix release`
  selecting the first release in the config file (`rel/config.exs`), and the
  environment which matches the current Mix environment (i.e. the value of `MIX_ENV`).
  """
  @shortdoc "Build a release for the current mix application"
  use Mix.Task
  alias Mix.Releases.{Config, Release, Profile, Logger, Assembler, Archiver, Errors}

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    # Parse options
    opts = parse_args(args)
    verbosity = Keyword.get(opts, :verbosity)
    Logger.configure(verbosity)

    # make sure we've compiled latest
    Mix.Task.run("compile", [])
    # make sure loadpaths are updated
    Mix.Task.run("loadpaths", [])

    # load release configuration
    Logger.debug("Loading configuration..")

    case Config.get(opts) do
      {:error, {:config, :not_found}} ->
        Logger.error("You are missing a release config file. Run the release.init task first")
        System.halt(1)

      {:error, {:config, reason}} ->
        Logger.error("Failed to load config:\n    #{reason}")
        System.halt(1)

      {:ok, config} ->
        archive? = not Keyword.get(opts, :no_tar, false)
        Logger.info("Assembling release..")
        do_release(config, archive?: archive?)
    end
  end

  defp do_release(config, archive?: false) do
    case Assembler.assemble(config) do
      {:ok, %Release{name: name} = release} ->
        print_success(release, name)

      {:error, _} = err ->
        Logger.error(Errors.format_error(err))
        System.halt(1)
    end
  rescue
    e ->
      Logger.error(
        "Release failed: #{Exception.message(e)}\n" <>
          Exception.format_stacktrace(System.stacktrace())
      )

      System.halt(1)
  end

  defp do_release(config, archive?: true) do
    case Assembler.assemble(config) do
      {:ok, %Release{name: name, profile: %Profile{dev_mode: true, executable: false}} = release} ->
        Logger.warn("You have set dev_mode to true, skipping archival phase")
        print_success(release, name)

      {:ok, %Release{name: name} = release} ->
        Logger.info("Packaging release..")

        case Archiver.archive(release) do
          {:ok, _archive_path} ->
            print_success(release, name)

          {:error, _} = err ->
            Logger.error(Errors.format_error(err))
            System.halt(1)
        end

      {:error, _} = err ->
        Logger.error(Errors.format_error(err))
        System.halt(1)
    end
  rescue
    e ->
      Logger.error(
        "Release failed: #{Exception.message(e)}\n" <>
          Exception.format_stacktrace(System.stacktrace())
      )

      System.halt(1)
  end

  @spec print_success(Release.t(), atom) :: :ok
  defp print_success(%{profile: %{output_dir: output_dir, executable: executable?}}, app) do
    relative_output_dir = Path.relative_to_cwd(output_dir)

    app =
      if executable? do
        "#{app}.run"
      else
        case :os.type() do
          {:win32, _} -> "#{app}.bat"
          {:unix, _} -> "#{app}"
        end
      end

    bin = Path.join([relative_output_dir, "bin", app])

    Logger.success("Release succesfully built!\n")
    IO.puts(
      """
      #{Logger.colorize("To start the release you have built, you can use one of the following tasks:", IO.ANSI.green)}

          # start a shell, like 'iex -S mix'
          #{Logger.colorize("> #{bin} ", IO.ANSI.cyan)}#{Logger.colorize("console", IO.ANSI.white)}

          # start in the foreground, like 'mix run --no-halt'
          #{Logger.colorize("> #{bin} ", IO.ANSI.cyan)}#{Logger.colorize("foreground", IO.ANSI.white)}

          # start in the background, must be stopped with the 'stop' command
          #{Logger.colorize("> #{bin} ", IO.ANSI.cyan)}#{Logger.colorize("start", IO.ANSI.white)}

      #{Logger.colorize("If you started a release elsewhere, and wish to connect to it:", IO.ANSI.green)}

          # connects a local shell to the running node
          #{Logger.colorize("> #{bin} ", IO.ANSI.cyan)}#{Logger.colorize("remote_console", IO.ANSI.white)}

          # connects directly to the running node's shell
          #{Logger.colorize("> #{bin} ", IO.ANSI.cyan)}#{Logger.colorize("attach", IO.ANSI.white)}

      #{Logger.colorize("For a complete listing of commands and their use:", IO.ANSI.green)}

          #{Logger.colorize("> #{bin} ", IO.ANSI.cyan)}#{Logger.colorize("help", IO.ANSI.white)}
      """)
  end

  @doc false
  @spec parse_args(OptionParser.argv()) :: Keyword.t() | no_return
  @spec parse_args(OptionParser.argv(), Keyword.t()) :: Keyword.t() | no_return
  def parse_args(argv, opts \\ []) do
    switches = [
      silent: :boolean,
      quiet: :boolean,
      verbose: :boolean,
      executable: :boolean,
      transient: :boolean,
      dev: :boolean,
      erl: :string,
      run_erl_env: :string,
      no_tar: :boolean,
      upgrade: :boolean,
      upfrom: :string,
      name: :string,
      profile: :string,
      env: :string,
      no_warn_missing: :boolean,
      warnings_as_errors: :boolean
    ]

    flags =
      if Keyword.get(opts, :strict, true) do
        {flags, _} = OptionParser.parse!(argv, strict: switches)
        flags
      else
        {flags, _, _} = OptionParser.parse(argv, strict: switches)
        flags
      end

    defaults = %{
      verbosity: :normal,
      selected_release: :default,
      selected_environment: :default,
      executable: false,
      is_upgrade: false,
      exec_opts: [transient: false],
      no_tar: false,
      upgrade_from: :latest
    }

    do_parse_args(flags, defaults)
  end

  defp do_parse_args([], acc), do: Map.to_list(acc)

  defp do_parse_args([{:verbose, _} | rest], acc) do
    do_parse_args(rest, Map.put(acc, :verbosity, :verbose))
  end

  defp do_parse_args([{:quiet, _} | rest], acc) do
    do_parse_args(rest, Map.put(acc, :verbosity, :quiet))
  end

  defp do_parse_args([{:silent, _} | rest], acc) do
    do_parse_args(rest, Map.put(acc, :verbosity, :silent))
  end

  defp do_parse_args([{:profile, profile} | rest], acc) do
    case String.split(profile, ":", trim: true, parts: 2) do
      [rel, env] ->
        new_acc =
          acc
          |> Map.put(:selected_release, rel)
          |> Map.put(:selected_environment, env)

        do_parse_args(rest, new_acc)

      other ->
        Logger.error("invalid profile name `#{other}`, must be `name:env`")
        System.halt(1)
    end
  end

  defp do_parse_args([{:name, name} | rest], acc) do
    do_parse_args(rest, Map.put(acc, :selected_release, String.to_atom(name)))
  end

  defp do_parse_args([{:env, name} | rest], acc) do
    do_parse_args(rest, Map.put(acc, :selected_environment, String.to_atom(name)))
  end

  defp do_parse_args([{:no_warn_missing, true} | rest], acc) do
    Application.put_env(:distillery, :no_warn_missing, true)
    do_parse_args(rest, acc)
  end

  defp do_parse_args([{:no_warn_missing, apps} | rest], acc) when is_list(apps) do
    Application.put_env(:distillery, :no_warn_missing, apps)
    do_parse_args(rest, acc)
  end

  defp do_parse_args([{:no_tar, _} | rest], acc) do
    do_parse_args(rest, Map.put(acc, :no_tar, true))
  end

  defp do_parse_args([{:executable, _} | _rest], %{is_upgrade: true}) do
    Logger.error("You cannot combine --executable with --upgrade")
    System.halt(1)
  end

  defp do_parse_args([{:executable, _} | rest], acc) do
    case :os.type() do
      {:win32, _} ->
        Logger.error("--executable is not supported on Windows")
        System.halt(1)

      _ ->
        do_parse_args(rest, Map.put(acc, :executable, true))
    end
  end

  defp do_parse_args([{:upgrade, _} | _rest], %{executable: true}) do
    Logger.error("You cannot combine --executable with --upgrade")
    System.halt(1)
  end

  defp do_parse_args([{:upgrade, _} | rest], acc) do
    do_parse_args(rest, Map.put(acc, :is_upgrade, true))
  end

  defp do_parse_args([{:warnings_as_errors, _} | rest], acc) do
    Application.put_env(:distillery, :warnings_as_errors, true)
    do_parse_args(rest, acc)
  end

  defp do_parse_args([{:transient, _} | rest], acc) do
    exec_opts =
      acc
      |> Map.get(:exec_opts, [])
      |> Keyword.put(:transient, true)

    do_parse_args(rest, Map.put(acc, :exec_opts, exec_opts))
  end
end
