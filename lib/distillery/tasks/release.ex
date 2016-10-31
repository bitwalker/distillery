defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

      # Build a release using defaults
      mix release

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
  alias Mix.Releases.{Release, Profile, Logger}

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

    # Apply override options
    config = case Keyword.get(opts, :dev_mode) do
               nil -> config
               m   -> %{config | :dev_mode => m}
             end
    config = case Keyword.get(opts, :erl_opts) do
               nil -> config
               o   -> %{config | :erl_opts => o}
             end
    config = %{config |
               :is_upgrade => Keyword.fetch!(opts, :is_upgrade),
               :upgrade_from => Keyword.fetch!(opts, :upgrade_from),
               :selected_environment => Keyword.fetch!(opts, :selected_environment),
               :selected_release => Keyword.fetch!(opts, :selected_release)}
    no_tar? = Keyword.get(opts, :no_tar)

    # build release
    Logger.info "Assembling release.."
    case {Mix.Releases.Assembler.assemble(config), no_tar?} do
      {{:ok, %Release{:name => name} = release}, true} ->
        print_success(release, name)
      {{:ok, %Release{:name => name, profile: %Profile{:dev_mode => true}} = release}, false} ->
        Logger.warn "You have set dev_mode to true, skipping archival phase"
        print_success(release, name)
      {{:ok, %Release{:name => name} = release}, false} ->
        Logger.info "Packaging release.."
        case Mix.Releases.Archiver.archive(release) do
          {:ok, _archive_path} ->
            print_success(release, name)
          {:error, reason} when is_binary(reason) ->
            Logger.error "Problem generating release tarball:\n    " <>
              reason
            exit({:shutdown, 1})
          {:error, reason} ->
            Logger.error "Problem generating release tarball:\n    " <>
              "#{inspect reason}"
            exit({:shutdown, 1})
        end
      {{:error, reason},_} when is_binary(reason) ->
        Logger.error "Failed to build release:\n    " <>
          reason
        exit({:shutdown, 1})
      {{:error, reason},_} ->
        Logger.error "Failed to build release:\n    " <>
          "#{inspect reason}"
        exit({:shutdown, 1})
    end
  end

  @spec print_success(Release.t, atom) :: :ok
  defp print_success(%Release{profile: %Profile{output_dir: output_dir}}, app) do
    relative_output_dir = Path.relative_to_cwd(output_dir)
    Logger.success "Release successfully built!\n    " <>
      "You can run it in one of the following ways:\n      " <>
      "Interactive: #{relative_output_dir}/bin/#{app} console\n      " <>
      "Foreground: #{relative_output_dir}/bin/#{app} foreground\n      " <>
      "Daemon: #{relative_output_dir}/bin/#{app} start"
  end

  @spec parse_args(OptionParser.argv) :: Keyword.t | no_return
  defp parse_args(argv) do
    switches = [silent: :boolean, quiet: :boolean, verbose: :boolean,
                dev: :boolean, erl: :string, no_tar: :boolean,
                upgrade: :boolean, upfrom: :string, name: :string,
                env: :string, no_warn_missing: :boolean,
                warnings_as_errors: :boolean]
    {overrides, _} = OptionParser.parse!(argv, switches)
    verbosity = :normal
    verbosity = cond do
      Keyword.get(overrides, :verbose, false) -> :verbose
      Keyword.get(overrides, :quiet, false)   -> :quiet
      Keyword.get(overrides, :silent, false)  -> :silent
      :else -> verbosity
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
    # Set warnings_as_errors
    Application.put_env(:distillery, :warnings_as_errors, Keyword.get(overrides, :warnings_as_errors, false))
    # Return options
    [verbosity: verbosity,
     selected_release: rel,
     selected_environment: env,
     dev_mode: Keyword.get(overrides, :dev),
     erl_opts: Keyword.get(overrides, :erl),
     no_tar:   Keyword.get(overrides, :no_tar, false),
     is_upgrade:   Keyword.get(overrides, :upgrade, false),
     upgrade_from: Keyword.get(overrides, :upfrom, :latest)]
  end
end
