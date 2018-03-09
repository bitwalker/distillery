defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

      # Build a release using defaults
      mix release

      # Build an executable release
      mix release --executable

      # Build an executable release which will cleanup after itself after it runs
      mix release --executable --transient

      # Build an upgrade release
      mix release --upgrade

      # Build an upgrade release from a specific version
      mix release --upgrade --upfrom=0.1.0

      # Build a specific release
      mix release --name=myapp

      # Build a release for a specific environment
      mix release --env=staging

      # Build a specific profile
      mix release --profile=myapp:staging

      # Pass args to erlexec when running the release
      mix release --erl="-env TZ UTC"

      # Enable dev mode. Make changes, compile using MIX_ENV=prod
      # and execute your release again to pick up the changes
      mix release --dev

      # Mute logging output
      mix release --silent

      # Quiet logging output
      mix release --quiet

      # Verbose logging output
      mix release --verbose

      # Do not package release, just assemble it
      mix release --no-tar

      # Treat warnings as errors
      mix release --warnings-as-errors

      # Skip warnings about missing applications
      mix release --no-warn-missing

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
      cond do
        executable? ->
          "#{app}.run"

        :else ->
          case :os.type() do
            {:win32, _} -> "#{app}.bat"
            {:unix, _} -> "#{app}"
          end
      end

    Logger.success(
      "Release successfully built!\n    " <>
        "You can run it in one of the following ways:\n      " <>
        "Interactive: #{relative_output_dir}/bin/#{app} console\n      " <>
        "Foreground: #{relative_output_dir}/bin/#{app} foreground\n      " <>
        "Daemon: #{relative_output_dir}/bin/#{app} start"
    )
  end

  @spec parse_args(OptionParser.argv()) :: Keyword.t() | no_return
  defp parse_args(argv) do
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

    {flags, _} = OptionParser.parse!(argv, strict: switches)

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

    parse_args(flags, defaults)
  end

  defp parse_args([], acc), do: Map.to_list(acc)

  defp parse_args([{:verbose, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :verbosity, :verbose))
  end

  defp parse_args([{:quiet, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :verbosity, :quiet))
  end

  defp parse_args([{:silent, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :verbosity, :silent))
  end

  defp parse_args([{:profile, profile} | rest], acc) do
    case String.split(profile, ":", trim: true, parts: 2) do
      [rel, env] ->
        new_acc =
          acc
          |> Map.put(:selected_release, rel)
          |> Map.put(:selected_environment, env)

        parse_args(rest, new_acc)

      other ->
        Logger.error("invalid profile name `#{other}`, must be `name:env`")
        System.halt(1)
    end
  end

  defp parse_args([{:name, name} | rest], acc) do
    parse_args(rest, Map.put(acc, :selected_release, String.to_atom(name)))
  end

  defp parse_args([{:env, name} | rest], acc) do
    parse_args(rest, Map.put(acc, :selected_environment, String.to_atom(name)))
  end

  defp parse_args([{:no_warn_missing, true} | rest], acc) do
    Application.put_env(:distillery, :no_warn_missing, true)
    parse_args(rest, acc)
  end

  defp parse_args([{:no_warn_missing, apps} | rest], acc) when is_list(apps) do
    Application.put_env(:distillery, :no_warn_missing, apps)
    parse_args(rest, acc)
  end

  defp parse_args([{:executable, _} | _rest], %{is_upgrade: true}) do
    Logger.error("You cannot combine --executable with --upgrade")
    System.halt(1)
  end

  defp parse_args([{:executable, _} | rest], acc) do
    case :os.type() do
      {:win32, _} ->
        Logger.error("--executable is not supported on Windows")
        System.halt(1)

      _ ->
        parse_args(rest, Map.put(acc, :executable, true))
    end
  end

  defp parse_args([{:upgrade, _} | _rest], %{executable: true}) do
    Logger.error("You cannot combine --executable with --upgrade")
    System.halt(1)
  end

  defp parse_args([{:upgrade, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :is_upgrade, true))
  end

  defp parse_args([{:warnings_as_errors, _} | rest], acc) do
    Application.put_env(:distillery, :warnings_as_errors, true)
    parse_args(rest, acc)
  end

  defp parse_args([{:transient, _} | rest], acc) do
    exec_opts =
      acc
      |> Map.get(:exec_opts, [])
      |> Keyword.put(:transient, true)

    parse_args(rest, Map.put(acc, :exec_opts, exec_opts))
  end
end
