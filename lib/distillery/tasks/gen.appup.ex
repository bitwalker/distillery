defmodule Mix.Tasks.Distillery.Gen.Appup do
  @moduledoc """
  Generate appup files for hot upgrades and downgrades

  ## Examples

      # Generate an appup for :test from the last known version to the current version
      mix distillery.gen.appup --app=test

      # Generate an appup for :test from a specific version to the current version
      mix distillery.gen.appup --app=test --upfrom=0.1.0

  The generated appup will be written to `rel/appups/<app>/<from>_to_<to>.appup`. You may name
  appups anything you wish in this directory, as long as they have a `.appup` extension. When you
  build a release, the appup generator will look for missing appups in this directory structure, and
  scan all `.appup` files for matching versions. If you have multiple appup files which match the current
  release, then the first one encountered will take precedence, which more than likely will depend on the
  sort order of the names.

  This task will take all of the same flags as `mix distillery.release`, but only uses them to determine the release
  configuration to use when determining application locations and versions.
  """
  @shortdoc "Generate appup files for hot upgrades and downgrades"

  use Mix.Task

  alias Distillery.Releases.Shell
  alias Distillery.Releases.Config
  alias Distillery.Releases.Release
  alias Distillery.Releases.Errors
  alias Distillery.Releases.Assembler
  alias Distillery.Releases.Appup
  alias Distillery.Releases.Utils

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    # Parse options
    primary_opts = Mix.Tasks.Distillery.Release.parse_args(args, strict: false)
    secondary_opts = parse_args(args)
    opts = Keyword.merge(primary_opts, secondary_opts)
    verbosity = Keyword.get(opts, :verbosity)
    Shell.configure(verbosity)

    # make sure we've compiled latest
    Mix.Task.run("compile", [])
    # make sure loadpaths are updated
    Mix.Task.run("loadpaths", [])

    # load release configuration
    Shell.debug("Loading configuration..")

    case Config.get(opts) do
      {:error, {:config, :not_found}} ->
        Shell.error("You are missing a release config file. Run the distillery.init task first")
        System.halt(1)

      {:error, {:config, reason}} ->
        Shell.error("Failed to load config:\n    #{reason}")
        System.halt(1)

      {:ok, config} ->
        with {:ok, release} <- Assembler.pre_assemble(config),
             :ok <- do_gen_appup(release, opts) do
          Shell.success(
            "You can find your generated appups in rel/appups/<app>/ with the .appup extension"
          )
        else
          {:error, _} = err ->
            Shell.error(Errors.format_error(err))
            System.halt(1)
        end
    end
  end

  defp do_gen_appup(
         %Release{profile: %{output_dir: output_dir, appup_transforms: transforms}},
         opts
       ) do
    app = opts[:app]
    # Does app exist?
    case Application.load(app) do
      :ok ->
        :ok

      {:error, {:already_loaded, _}} ->
        :ok

      {:error, _} ->
        Shell.error("Unable to locate an app called '#{app}'")
        System.halt(1)
    end

    v2 =
      app
      |> Application.spec()
      |> Keyword.get(:vsn)
      |> List.to_string()

    v2_path = Application.app_dir(app)

    # Look for app versions in release directory
    available_versions =
      Path.join([output_dir, "lib", "#{app}-*"])
      |> Path.wildcard()
      |> Enum.map(fn appdir ->
        {:ok, [{:application, ^app, meta}]} =
          Path.join([appdir, "ebin", "#{app}.app"])
          |> Utils.read_terms()

        version =
          meta
          |> Keyword.fetch!(:vsn)
          |> List.to_string()

        {version, appdir}
      end)
      |> Map.new()
      |> Map.delete(v2)

    sorted_versions =
      available_versions
      |> Map.keys()
      |> Utils.sort_versions()

    if map_size(available_versions) == 0 do
      Shell.error("No available upfrom versions for #{app}")
      System.halt(1)
    end

    {v1, v1_path} =
      case opts[:upgrade_from] do
        :latest ->
          version = List.first(sorted_versions)
          {version, Map.fetch!(available_versions, version)}

        version ->
          case Map.get(available_versions, version) do
            nil ->
              Shell.error("Version #{version} of #{app} is not available!")
              System.halt(1)

            path ->
              {version, path}
          end
      end

    case Appup.make(app, v1, v2, v1_path, v2_path, transforms) do
      {:error, _} = err ->
        err

      {:ok, appup} ->
        Shell.info("Generated .appup for #{app} #{v1} -> #{v2}")
        appup_path = Path.join(["rel", "appups", "#{app}", "#{v1}_to_#{v2}.appup"])
        File.mkdir_p!(Path.dirname(appup_path))
        :ok = Utils.write_term(appup_path, appup)
    end
  end

  defp parse_args(argv) do
    opts = [
      switches: [
        app: :string
      ]
    ]

    {flags, _, _} = OptionParser.parse(argv, opts)

    defaults = %{
      app: nil
    }

    parse_args(flags, defaults)
  end

  defp parse_args([], %{app: nil}) do
    Shell.error("This task requires --app=<app_name> to be passed")
    System.halt(1)
  end

  defp parse_args([], opts), do: Map.to_list(opts)

  defp parse_args([{:app, app} | rest], opts) do
    parse_args(rest, Map.put(opts, :app, String.to_atom(app)))
  end

  defp parse_args([_ | rest], opts), do: parse_args(rest, opts)
end
