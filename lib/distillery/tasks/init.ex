defmodule Mix.Tasks.Distillery.Init do
  @moduledoc """
  Prepares a new project for use with releases.
  This simply creates a `rel` directory in the project root,
  and creates a basic initial configuration file in `rel/config.exs`.
  It will also creates a vm.args file in `rel/vm.args` to tweak the
  configuration of the BEAM.

  After running this, you can build a release right away with `mix distillery.release`,
  but it is recommended you review the config file to understand its contents.

  ## Examples

      # Initialize releases, with a fully commented config file
      mix distillery.init

      # Initialize releases, but with no comments in the config file
      mix distillery.init --no-doc

      # For umbrella projects, generate a config where each app
      # in the umbrella is its own release, rather than all
      # apps under a single release
      mix distillery.init --release-per-app

      # Name the release, by default the current application name
      # will be used, or in the case of umbrella projects, the name
      # of the directory in which the umbrella project resides, with
      # invalid characters replaced or stripped out.
      mix distillery.init --name foobar

      # Use a custom template for generating the release config.
      mix distillery.init --template path/to/template

  """
  @shortdoc "initialize a new release configuration"
  use Mix.Task

  alias Distillery.Releases.Utils
  alias Distillery.Releases.Shell

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    # make sure loadpaths are updated
    Mix.Task.run("loadpaths", [])
    # make sure we're compiled too
    Mix.Task.run("compile", [])

    Shell.configure(:normal)

    opts = parse_args(args)

    # Generate template bindings based on type of project and task opts
    bindings =
      if Mix.Project.umbrella?() do
        get_umbrella_bindings(opts)
      else
        get_standard_bindings(opts)
      end

    # Create /rel
    File.mkdir_p!("rel/plugins")

    # Generate .gitignore for plugins folder
    unless File.exists?("rel/plugins/.gitignore") do
      File.write!("rel/plugins/.gitignore", "*.*\n!*.exs\n!.gitignore", [:utf8])
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

    # Generate vm.args
    vm_args = Path.join("rel", "vm.args")
    unless File.exists?(vm_args) do
      {:ok, vm} = Utils.template("vm.args.default", bindings)
      File.write!(vm_args, vm)
    end

    IO.puts(
      IO.ANSI.cyan() <>
        "\nAn example config file has been placed in rel/config.exs, review it,\n" <>
        "make edits as needed/desired, and then run `mix distillery.release` to build the release" <>
        IO.ANSI.reset()
    )
  rescue
    e in [File.Error] ->
      Shell.error("Initialization failed:\n    #{Exception.message(e)}")
      System.halt(1)
  end

  @spec parse_args([String.t()]) :: Keyword.t() | no_return
  defp parse_args(argv) do
    opts = [
      strict: [
        no_doc: :boolean,
        release_per_app: :boolean,
        name: :string,
        template: :string
      ]
    ]

    {overrides, _} = OptionParser.parse!(argv, opts)

    defaults = [
      no_doc: false,
      release_per_app: false,
      name: nil,
      template: nil
    ]

    Keyword.merge(defaults, overrides)
  end

  @spec get_umbrella_bindings(Keyword.t()) :: Keyword.t() | no_return
  defp get_umbrella_bindings(opts) do
    apps_path = Keyword.get(Mix.Project.config(), :apps_path)
    apps_paths = Path.wildcard("#{apps_path}/*")

    apps =
      apps_paths
      |> Enum.map(fn app_path ->
        mixfile = Path.join(app_path, "mix.exs")
        app = get_app_name_from_ast(mixfile)
        {app, :permanent}
      end)

    release_per_app? = Keyword.get(opts, :release_per_app, false)

    releases =
      if release_per_app? do
        for {app, start_type} <- apps do
          [
            release_name: app,
            is_umbrella: false,
            release_applications: [{app, start_type}]
          ]
        end
      else
        release_name_from_cwd = String.replace(Path.basename(File.cwd!()), "-", "_")
        release_name = Keyword.get(opts, :name, release_name_from_cwd) || release_name_from_cwd

        [
          [
            release_name: String.to_atom(release_name),
            is_umbrella: true,
            release_applications: apps
          ]
        ]
      end

    [{:releases, releases} | get_common_bindings(opts)]
  end

  @spec get_standard_bindings(Keyword.t()) :: Keyword.t() | no_return
  defp get_standard_bindings(opts) do
    app = Keyword.get(Mix.Project.config(), :app)

    releases = [
      [
        # If opts contains the key :name, but its value is nil, we still want to default to app
        release_name: Keyword.get(opts, :name, app) || app,
        is_umbrella: false,
        release_applications: [{app, :permanent}]
      ]
    ]

    [{:releases, releases} | get_common_bindings(opts)]
  end

  @spec get_common_bindings(Keyword.t()) :: Keyword.t()
  defp get_common_bindings(opts) do
    [
      no_docs: Keyword.get(opts, :no_doc, false),
      cookie: Distillery.Cookies.get(),
      get_cookie: &Distillery.Cookies.get/0
    ]
  end

  def get_app_name_from_ast(path) do
    cwd = File.cwd!()

    try do
      app_dir = Path.dirname(path)
      relative_path = Path.relative_to(path, app_dir)
      File.cd!(app_dir)

      {{:module, mod, _, _}, _bindings} =
        relative_path
        |> File.read!()
        |> Code.string_to_quoted!()
        |> Code.eval_quoted(
          [],
          aliases: [{Mix, __MODULE__.MixMock}],
          requires: [],
          macros: [{__MODULE__.MixMock, [defmodule: 2]}]
        )

      mod.project[:app]
    rescue
      err ->
        raise "Problem reading mix.exs at #{path}:\n\n#{Exception.message(err)}\n" <>
                Exception.format_stacktrace()
    after
      File.cd!(cwd)
    end
  end

  # Used to fake out Mix/Mix.Project when reading mixfiles
  defmodule MixMock.Project do
    @moduledoc false
    defmacro __using__(_) do
      quote do
        :ok
      end
    end
  end

  defmodule MixMock do
    @moduledoc false
    require MixMock.Project

    def env, do: :dev

    def compilers, do: []

    # We override defmodule so that we can make sure the modules
    # don't conflict with any already loaded
    defmacro defmodule(name, do: body) do
      quote do
        conflict_free_name = Module.concat([unquote(__MODULE__), unquote(name)])
        require Kernel

        Kernel.defmodule conflict_free_name do
          import Kernel
          unquote(body)
        end
      end
    end
  end
end
