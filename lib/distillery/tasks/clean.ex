defmodule Mix.Tasks.Distillery.Release.Clean do
  @moduledoc """
  Cleans release artifacts from the current project.

  ## Examples

      # Cleans files associated with the latest release
      mix distillery.release.clean

      # Remove all release files
      mix distillery.release.clean --implode

      # Remove all release files, and do it without confirmation
      mix distillery.release.clean --implode --no-confirm

      # Log verbosely
      mix distillery.release.clean --verbose

  """
  @shortdoc "Clean up any release-related files"
  use Mix.Task

  alias Distillery.Releases.Shell
  alias Distillery.Releases.App
  alias Distillery.Releases.Plugin
  alias Distillery.Releases.Release
  alias Distillery.Releases.Config
  alias Distillery.Releases.Profile
  alias Distillery.Releases.Errors

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    # Parse options
    opts = parse_args(args)
    verbosity = Keyword.get(opts, :verbosity)
    Shell.configure(verbosity)

    Application.load(:distillery)

    # make sure loadpaths are updated
    Mix.Task.run("loadpaths", [])
    # make sure we're compiled too
    Mix.Task.run("compile", [])

    # load release configuration
    Shell.debug("Loading configuration..")
    config_path = Path.join([File.cwd!(), "rel", "config.exs"])

    config =
      case File.exists?(config_path) do
        true ->
          try do
            Config.read!(config_path)
          rescue
            e in [Config.LoadError] ->
              file = Path.relative_to_cwd(e.file)
              message = Exception.message(e)
              message = String.replace(message, "nofile", file)
              Shell.error("Failed to load config:\n    #{message}")
              System.halt(1)
          end

        false ->
          Shell.error("You are missing a release config file. Run the distillery.init task first")
          System.halt(1)
      end

    implode? = Keyword.get(opts, :implode, false)
    no_confirm? = Keyword.get(opts, :no_confirm, false)

    with {:ok, environment} <- Release.select_environment(config),
         {:ok, release} <- Release.select_release(config),
         release <- Release.apply_environment(release, environment),
         {:ok, release} <- Release.apply_configuration(release, config, true) do
      cond do
        implode? && no_confirm? ->
          clean_all!(release.profile.output_dir)

        implode? && confirm_implode?() ->
          clean_all!(release.profile.output_dir)

        :else ->
          clean!(config, args)
      end
    else
      {:error, _reason} = err ->
        err
        |> Errors.format_error()
        |> Shell.error()

        System.halt(1)
    end
  end

  @spec clean_all!(String.t()) :: :ok | no_return
  defp clean_all!(output_dir) do
    Shell.info("Cleaning all releases..")

    unless File.exists?(output_dir) do
      Shell.warn("Release output directory not found! Nothing to do.")
      exit(:normal)
    end

    File.rm_rf!(output_dir)
    Shell.success("Clean successful!")
  rescue
    e in [File.Error] ->
      Shell.error(
        "Unable to clean #{Path.relative_to_cwd(output_dir)}:\n\t#{Exception.message(e)}"
      )

      System.halt(1)
  end

  @spec clean!(Config.t(), [String.t()]) :: :ok | no_return
  defp clean!(%Config{releases: releases}, args) do
    # load release configuration
    Shell.info("Cleaning last release..")
    # clean release
    for {name, release} <- releases, File.exists?(release.profile.output_dir) do
      Shell.notice("    Removing release #{name}:#{release.version}")
      clean_release(release, args)
    end

    Shell.success("Clean successful!")
  end

  @spec clean_release(Release.t(), [String.t()]) :: :ok | {:error, term}
  defp clean_release(%Release{profile: %Profile{output_dir: output_dir}} = release, args) do
    # Remove erts
    output_dir
    |> Path.join("erts-*")
    |> Path.wildcard()
    |> Enum.each(&clean_path/1)

    # Remove libs
    case Release.apps(release) do
      {:error, _} = err ->
        Shell.warn(Errors.format_error(err))

      apps ->
        for %App{name: name, vsn: vsn} <- apps do
          clean_path(Path.join([Release.lib_path(release), "#{name}-#{vsn}"]))
        end
    end

    # Remove releases/start_erl.data
    clean_path(Path.join([output_dir, "releases", "start_erl.data"]))

    # Remove current release version
    clean_path(Release.version_path(release))

    # Execute plugin callbacks for this release
    Plugin.after_cleanup(release, args)
  end

  defp clean_path(path) do
    File.rm_rf!(path)
  rescue
    e in [File.Error] ->
      Shell.error("Unable to clean #{path}:\n    #{Exception.message(e)}")
      System.halt(1)
  end

  @spec parse_args([String.t()]) :: Keyword.t() | no_return
  defp parse_args(argv) do
    opts = [
      strict: [
        implode: :boolean,
        no_confirm: :boolean,
        verbose: :boolean,
        silent: :boolean
      ]
    ]

    {overrides, _} = OptionParser.parse!(argv, opts)

    defaults = %{
      verbosity: :normal,
      implode: false,
      no_confirm: false
    }

    parse_args(overrides, defaults)
  end

  defp parse_args([], acc), do: Map.to_list(acc)

  defp parse_args([{:verbose, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :verbosity, :verbose))
  end

  defp parse_args([{:silent, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :verbosity, :silent))
  end

  defp parse_args([{:implode, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :implode, true))
  end

  defp parse_args([{:no_confirm, _} | rest], acc) do
    parse_args(rest, Map.put(acc, :no_confirm, true))
  end

  defp confirm_implode? do
    Shell.confirm?("""
    THIS WILL REMOVE ALL RELEASES AND RELATED CONFIGURATION!
    Are you absolutely sure you want to proceed?
    """)
  end
end
