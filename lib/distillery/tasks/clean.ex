defmodule Mix.Tasks.Release.Clean do
  @moduledoc """
  Cleans release artifacts from the current project.

  ## Examples

      # Cleans files associated with the latest release
      mix release.clean

      # Remove all release files
      mix release.clean --implode

      # Remove all release files, and do it without confirmation
      mix release.clean --implode --no-confirm

      # Log verbosely
      mix release.clean --verbose

  """
  @shortdoc "Clean up any release-related files"
  use Mix.Task
  alias Mix.Releases.{Logger, App, Utils, Plugin, Assembler, Release, Config, Profile}

  @spec run(OptionParser.argv) :: no_return
  def run(args) do
    # Parse options
    opts = parse_args(args)
    verbosity = Keyword.get(opts, :verbosity)
    Logger.configure(verbosity)

    Application.load(:distillery)

    # make sure loadpaths are updated
    Mix.Task.run("loadpaths", [])
    # make sure we're compiled too
    Mix.Task.run("compile", [])

    opts = parse_args(args)

    # load release configuration
    Logger.debug "Loading configuration.."
    config_path = Path.join([File.cwd!, "rel", "config.exs"])
    config = case File.exists?(config_path) do
               true ->
                 try do
                   Mix.Releases.Config.read!(config_path)
                 rescue
                   e in [Mix.Releases.Config.LoadError]->
                     file = Path.relative_to_cwd(e.file)
                     message = e.error.__struct__.message(e.error)
                     message = String.replace(message, "nofile", file)
                     Logger.error "Failed to load config:\n" <>
                       "    #{message}"
                     exit({:shutdown, 1})
                 end
               false ->
                 Logger.error "You are missing a release config file. Run the release.init task first"
                 exit({:shutdown, 1})
             end

    implode?    = Keyword.get(opts, :implode, false)
    no_confirm? = Keyword.get(opts, :no_confirm, false)
    with {:ok, environment} <- Assembler.select_environment(config),
         {:ok, release}     <- Assembler.select_release(config),
         {:ok, release}     <- Assembler.apply_environment(release, environment),
         {:ok, release}     <- Assembler.apply_configuration(release, config) do
      cond do
        implode? && no_confirm? ->
          clean_all!(release.profile.output_dir)
        implode? && confirm_implode?() ->
          clean_all!(release.profile.output_dir)
        :else ->
          clean!(config, args)
      end
    end

  end

  @spec clean_all!(String.t) :: :ok | no_return
  defp clean_all!(output_dir) do
    Logger.info "Cleaning all releases.."
    unless File.exists?(output_dir) do
      Logger.warn "Release output directory not found! Nothing to do."
      exit(:normal)
    end
    File.rm_rf!(output_dir)
    Logger.success "Clean successful!"
  end

  @spec clean!(Mix.Releases.Config.t, [String.t]) :: :ok | no_return
  defp clean!(%Config{releases: releases}, args) do
    # load release configuration
    Logger.info "Cleaning last release.."
    # clean release
    for {name, release} <- releases, File.exists?(release.profile.output_dir) do
      Logger.notice "    Removing release #{name}:#{release.version}"
      clean_release(release, args)
    end
    Logger.success "Clean successful!"
  end

  @spec clean_release(Release.t, [String.t]) :: :ok | :no_return
  defp clean_release(%Release{profile: %Profile{output_dir: output_dir}} = release, args) do
    # Remove erts
    erts_paths = Path.wildcard(Path.join(output_dir, "erts-*"))
    for erts <- erts_paths do
      File.rm_rf!(erts)
    end
    # Remove libs
    for %App{name: name, vsn: vsn} <- Utils.get_apps(release) do
      File.rm_rf!(Path.join([output_dir, "lib", "#{name}-#{vsn}}"]))
    end
    # Remove releases/start_erl.data
    File.rm(Path.join([output_dir, "releases", "start_erl.data"]))
    # Remove current release version
    File.rm_rf!(Path.join([output_dir, "releases", "#{release.version}"]))
    # Execute plugin callbacks for this release
    Plugin.after_cleanup(release, args)
  end

  @spec parse_args([String.t]) :: Keyword.t | no_return
  defp parse_args(argv) do
    {overrides, _} = OptionParser.parse!(argv, [
          implode: :boolean,
          no_confirm: :boolean,
          verbose: :boolean])
    verbosity = case Keyword.get(overrides, :verbose) do
                  true -> :verbose
                  _    -> :normal
                end
    [implode: Keyword.get(overrides, :implode, false),
      no_confirm: Keyword.get(overrides, :no_confirm, false),
      verbosity: verbosity]
  end

  @spec confirm_implode?() :: boolean
  defp confirm_implode? do
    Distillery.IO.confirm """
    THIS WILL REMOVE ALL RELEASES AND RELATED CONFIGURATION!
    Are you absolutely sure you want to proceed?
    """
  end
end
