defmodule Mix.Tasks.Release.Init do
  @moduledoc """
  Prepares a new project for use with releases.
  This simply creates a `rel` directory in the project root,
  and creates a basic initial configuration file in `rel/config.exs`.

  After running this, you can build a release right away with `mix release`,
  but it is recommended you review the config file to understand its contents.

  ## Examples

      # Initialize releases, with a fully commented config file
      mix release.init

      # Initialize releases, but with no comments in the config file
      mix release.init --no-doc

      # For umbrella projects, generate a config where each app
      # in the umbrella is its own release, rather than all
      # apps under a single release
      mix release.init --release-per-app

      # Name the release, by default the current application name
      # will be used, or in the case of umbrella projects, the name
      # of the directory in which the umbrella project resides, with
      # invalid characters replaced or stripped out.
      mix release.init --name foobar

      # Use a custom template for generating the release config.
      mix release.init --template path/to/template

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
    File.mkdir_p!("rel/plugins")
    # Generate .gitignore for plugins folder
    unless File.exists?("rel/plugins/.gitignore") do
      File.write!("rel/plugins/.gitignore", "*.*\n!*.exs", [:utf8])
    end
    # Generate config.exs
    {:ok, config} =
      case opts[:template] do
        nil ->
          Utils.template(:example_config, bindings)
        template_path ->
          Utils.template_path(template_path, bindings)
      end

    # Save config.exs to /rel
    File.write!(Path.join("rel", "config.exs"), config)

    IO.puts(
      IO.ANSI.cyan <>
      "\nAn example config file has been placed in rel/config.exs, review it,\n" <>
      "make edits as needed/desired, and then run `mix release` to build the release" <>
      IO.ANSI.reset
    )
  rescue
    e in [File.Error] ->
      Logger.error "Initialization failed:\n" <>
        "    #{Exception.message(e)}"
      exit({:shutdown, 1})
  end

  @defaults [no_doc: false,
             release_per_app: false,
             name: nil,
             template: nil]
  @spec parse_args([String.t]) :: Keyword.t | no_return
  defp parse_args(argv) do
    {overrides, _} = OptionParser.parse!(argv,
      strict: [no_doc: :boolean,
               release_per_app: :boolean,
               name: :string,
               template: :string])
    Keyword.merge(@defaults, overrides)
  end

  @spec get_umbrella_bindings(Keyword.t) :: Keyword.t | no_return
  defp get_umbrella_bindings(opts) do
    apps_path = Keyword.get(Mix.Project.config, :apps_path)
    apps_paths = Path.wildcard("#{apps_path}/*")
    apps = apps_paths
      |> Enum.map(fn app_path ->
        Mix.Project.in_project(String.to_atom(Path.basename(app_path)), app_path, fn
          nil ->
            :ignore
          mixfile ->
            {Keyword.get(mixfile.project, :app), :permanent}
        end)
      end)
      |> Enum.filter(fn :ignore -> false; _ -> true end)
    release_per_app? = Keyword.get(opts, :release_per_app, false)
    if release_per_app? do
      [releases: Enum.map(apps, fn {app, start_type} ->
         [release_name: app,
          is_umbrella: false,
          release_applications: [{app, start_type}]]
       end)]
      ++ get_common_bindings(opts)
    else
      release_name_from_cwd = String.replace(Path.basename(File.cwd!), "-", "_")
      release_name = Keyword.get(opts, :name, release_name_from_cwd) || release_name_from_cwd
      [releases: [
         [release_name: String.to_atom(release_name),
          is_umbrella: true,
          release_applications: apps]]]
      ++ get_common_bindings(opts)
    end
  end

  @spec get_standard_bindings(Keyword.t) :: Keyword.t | no_return
  defp get_standard_bindings(opts) do
    app = Keyword.get(Mix.Project.config, :app)
    [releases: [
      [release_name: app,
       is_umbrella: false,
       release_applications: [{app, :permanent}]]]]
    ++ get_common_bindings(opts)
  end

  @spec get_common_bindings(Keyword.t) :: Keyword.t
  defp get_common_bindings(opts) do
    no_doc? = Keyword.get(opts, :no_doc, false)
    [no_docs: no_doc?,
     cookie: Distillery.Cookies.get,
     get_cookie: &Distillery.Cookies.get/0]
  end
end
