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

  @spec run(OptionParser.argv) :: no_return
  def run(args) do
    # Parse options
    opts = parse_args(args)
    verbosity = Keyword.get(opts, :verbosity)
    Logger.configure(verbosity)

    Application.load(:distillery)

    # make sure we've compiled latest
    Mix.Task.run("compile", [])
    # make sure loadpaths are updated
    Mix.Task.run("loadpaths", [])

    # load release configuration
    Logger.debug "Loading configuration.."
    case Config.get(opts) do
      {:error, {:config, :not_found}} ->
        Logger.error "You are missing a release config file. Run the release.init task first"
        exit({:shutdown, 1})
      {:error, {:config, reason}} ->
        Logger.error "Failed to load config:\n" <>
          "    #{reason}"
        exit({:shutdown, 1})
      {:ok, config} ->
        archive? = not Keyword.get(opts, :no_tar, false)
        Logger.info "Assembling release.."
        do_release(config, archive?: archive?)
    end
  end

  defp do_release(config, archive?: false) do
    case Assembler.assemble(config) do
      {:ok, %Release{name: name} = release} ->
        print_success(release, name)
      {:error, _} = err ->
        Logger.error Errors.format_error(err)
        exit({:shutdown, 1})
    end
  rescue
    e ->
      Logger.error "Release failed: " <>
        Exception.message(e) <>
        "\n#{Exception.format_stacktrace(System.stacktrace)}"
      exit({:shutdown, 1})
  end
  defp do_release(config, archive?: true) do
    case Assembler.assemble(config) do
      {:ok, %Release{name: name, profile: %Profile{dev_mode: true, executable: false}} = release} ->
        Logger.warn "You have set dev_mode to true, skipping archival phase"
        print_success(release, name)
      {:ok, %Release{name: name} = release} ->
        Logger.info "Packaging release.."
        case Archiver.archive(release) do
          {:ok, _archive_path} ->
            print_success(release, name)
          {:error, _} = err ->
            Logger.error Errors.format_error(err)
            exit({:shutdown, 1})
        end
      {:error, _} = err ->
        Logger.error Errors.format_error(err)
        exit({:shutdown, 1})
    end
  rescue
    e ->
      Logger.error "Release failed: " <>
        Exception.message(e) <>
        "\n#{Exception.format_stacktrace(System.stacktrace)}"
      exit({:shutdown, 1})
  end

  @spec print_success(Release.t, atom) :: :ok
  defp print_success(%Release{profile: %Profile{output_dir: output_dir, executable: executable?}}, app) do
    relative_output_dir = Path.relative_to_cwd(output_dir)
    app = cond do
      executable? -> "#{app}.run"
      :else ->
        case :os.type() do
          {:win32,_} -> "#{app}.bat"
          {:unix,_}  -> "#{app}"
        end
    end
    Logger.success "Release successfully built!\n    " <>
      "You can run it in one of the following ways:\n      " <>
      "Interactive: #{relative_output_dir}/bin/#{app} console\n      " <>
      "Foreground: #{relative_output_dir}/bin/#{app} foreground\n      " <>
      "Daemon: #{relative_output_dir}/bin/#{app} start"
  end

  @spec parse_args(OptionParser.argv) :: Keyword.t | no_return
  defp parse_args(argv) do
    switches = [silent: :boolean, quiet: :boolean, verbose: :boolean,
                executable: :boolean, transient: :boolean,
                dev: :boolean, erl: :string, run_erl_env: :string, no_tar: :boolean,
                upgrade: :boolean, upfrom: :string, name: :string, profile: :string,
                env: :string, no_warn_missing: :boolean,
                warnings_as_errors: :boolean]
    {overrides, _} = OptionParser.parse!(argv, strict: switches)
    verbosity = cond do
      Keyword.get(overrides, :verbose, false) -> :verbose
      Keyword.get(overrides, :quiet, false)   -> :quiet
      Keyword.get(overrides, :silent, false)  -> :silent
      :else -> :normal
    end
    {rel, env} = case Keyword.get(overrides, :profile) do
      nil ->
        rel = Keyword.get(overrides, :name, "default")
        env = Keyword.get(overrides, :env, "default")
        {String.to_atom(rel), String.to_atom(env)}
      profile ->
        case String.split(profile, ":", trim: true, parts: 2) do
          [rel, env] -> {String.to_atom(rel), String.to_atom(env)}
          other ->
            Logger.error "invalid profile name `#{other}`, must be `name:env`"
            exit({:shutdown, 1})
        end
    end
    # Handle warnings about missing applications
    cond do
      Keyword.get(overrides, :no_warn_missing, false) ->
        Application.put_env(:distillery, :no_warn_missing, true)
      :else ->
        case Application.get_env(:distillery, :no_warn_missing, false) do
          list when is_list(list) -> Application.put_env(:distillery, :no_warn_missing, [:distillery|list])
          false -> Application.put_env(:distillery, :no_warn_missing, [:distillery])
          _ -> :ok
        end
    end
    executable? = Keyword.get(overrides, :executable, false)
    is_upgrade? = Keyword.get(overrides, :upgrade, false)
    {os_type, _} = :os.type()
    cond do
      executable? && is_upgrade? ->
        Logger.error "You cannot combine --executable with --upgrade"
        exit({:shutdown, 1})
      executable? && os_type == :win32 ->
        Logger.error "--executable is not supported on Windows"
        exit({:shutdown, 1})
      :else ->
        :ok
    end
    # Set warnings_as_errors
    Application.put_env(:distillery, :warnings_as_errors, Keyword.get(overrides, :warnings_as_errors, false))
    exec_opts = [transient: Keyword.get(overrides, :transient, false)]
    # Return options
    [verbosity: verbosity,
     selected_release: rel,
     selected_environment: env,
     dev_mode: Keyword.get(overrides, :dev),
     erl_opts: Keyword.get(overrides, :erl),
     run_erl_env: Keyword.get(overrides, :run_erl_env),
     executable: executable?,
     exec_opts: exec_opts,
     no_tar:   Keyword.get(overrides, :no_tar, false),
     is_upgrade:   is_upgrade?,
     upgrade_from: Keyword.get(overrides, :upfrom, :latest)]
  end
end
