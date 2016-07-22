defmodule Mix.Tasks.Release.Init do
  @moduledoc """
  Prepares a new project for use with releases.
  This simply creates a `rel` directory in the project root,
  and creates a basic initial configuration file in `rel/config.exs`.

  After running this, you can build a release right away with `mix release`,
  but it is recommended you review the config file to understand it's contents.

  ## Examples

      # Initialize releases, with a fully commented config file
      mix release.init

      # Initialize releases, but with no comments in the config file
      mix release.init --no-doc

      # For umbrella projects, generate a config where each app
      # in the umbrella is it's own release, rather than all
      # apps under a single release
      mix release.init --release-per-app

      # Name the release, by default the current application name
      # will be used, or in the case of umbrella projects, the name
      # of the directory in which the umbrella project resides, with
      # invalid characters replaced or stripped out.
      mix release.init --name foobar

  """
  @shortdoc "initialize a new release configuration"
  use Mix.Task
  alias Mix.Releases.{Utils, Logger}

  @spec run(OptionParser.argv) :: no_return
  def run(args) do
    # make sure loadpaths are updated
    Mix.Task.run("loadpaths", [])
    # make sure we're compiled too
    Mix.Task.run("compile", [])

    Logger.configure(:debug)

    # Generate template bindings based on type of project and task opts
    opts = parse_args(args)
    bindings = case Mix.Project.umbrella? do
      true  -> get_umbrella_bindings(opts)
      false -> get_standard_bindings(opts)
    end
    # Create /rel
    File.mkdir_p!("rel")
    # Generate config.exs
    {:ok, config} = Utils.template(:example_config, bindings)
    # Save config.exs to /rel
    File.write!(Path.join("rel", "config.exs"), config)

    IO.puts(
      IO.ANSI.cyan <>
      "\nAn example config file has been placed in rel/config.exs, review it,\n" <>
      "make edits as needed/desired, and then run `mix release` to build the release" <>
      IO.ANSI.reset
    )
  end

  @defaults [no_doc: false,
             release_per_app: false]
  @spec parse_args([String.t]) :: Keyword.t | no_return
  defp parse_args(argv) do
    {overrides, _} = OptionParser.parse!(argv,
      strict: [no_doc: :boolean,
               release_per_app: :boolean])
    Keyword.merge(@defaults, overrides)
  end

  @spec get_umbrella_bindings(Keyword.t) :: Keyword.t | no_return
  defp get_umbrella_bindings(opts) do
    apps_path = Keyword.get(Mix.Project.config, :apps_path)
    apps_paths = File.ls!(apps_path)
    apps = apps_paths
      |> Enum.map(&Path.join(apps_path, &1))
      |> Enum.map(fn app_path ->
        Mix.Project.in_project(String.to_atom(Path.basename(app_path)), app_path, fn mixfile ->
          {Keyword.get(mixfile.project, :app), :permanent}
        end)
      end)
    no_doc? = Keyword.get(opts, :no_doc, false)
    release_per_app? = Keyword.get(opts, :release_per_app, false)
    if release_per_app? do
      [no_docs: no_doc?,
       releases: Enum.map(apps, fn {app, start_type} ->
         [release_name: app,
          is_umbrella: false,
          release_applications: [{app, start_type}]]
       end)]
    else
      release_name = String.replace(Path.basename(File.cwd!), "-", "_")
      [no_docs: no_doc?,
       releases: [
         [release_name: String.to_atom(release_name),
          is_umbrella: true,
          release_applications: apps]]]
    end
  end

  @spec get_standard_bindings(Keyword.t) :: Keyword.t | no_return
  defp get_standard_bindings(opts) do
    app = Keyword.get(Mix.Project.config, :app)
    no_doc? = Keyword.get(opts, :no_doc, false)
    [no_docs: no_doc?,
     releases: [
      [release_name: app,
       is_umbrella: false,
       release_applications: [{app, :permanent}]]]]
  end
end
