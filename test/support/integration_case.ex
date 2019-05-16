defmodule Distillery.Test.IntegrationCase do
  use ExUnit.CaseTemplate

  alias Distillery.Releases.Utils
  import Distillery.Test.Helpers

  @fixtures_path Path.join([__DIR__, "..", "fixtures"])

  @standard_app_path Path.join([@fixtures_path, "standard_app"])
  @standard_build_path Path.join([@standard_app_path, "_build", "prod"])
  @standard_output_path Path.join([@standard_build_path, "rel", "standard_app"])
  
  @umbrella_app_path Path.join([@fixtures_path, "umbrella_app"])
  @umbrella_build_path Path.join([@umbrella_app_path, "_build", "prod"])
  @umbrella_output_path Path.join([@umbrella_build_path, "rel", "umbrella"])
 
  using do
    quote do
      import unquote(__MODULE__)

      @moduletag integration: true
      @moduletag timeout: 60_000 * 5
    end
  end

  @doc "Run an integration test in the context of a standard application"
  defmacro with_standard_app(do: body) do
    quote do
      Process.put(:output_path, unquote(@standard_output_path))
      with_app unquote(@standard_app_path) do
        unquote(body)
      end
    end
  end
  
  @doc "Run an integration test in the context of an umbrella application"
  defmacro with_umbrella_app(do: body) do
    quote do
      Process.put(:output_path, unquote(@umbrella_output_path))
      with_app unquote(@umbrella_app_path) do
        unquote(body)
      end
    end
  end

  @doc "Perform some work in the context of some application"
  defmacro with_app(app_path, do: body) do
    quote do
      old_dir = File.cwd!()
      File.cd!(unquote(app_path))
      Process.put(:app_path, unquote(app_path))
      try do
        unquote(body)
      after
        Process.delete(:app_path)
        File.cd!(old_dir)
      end
    end
  end

  setup_all do
    for app_path <- [@standard_app_path, @umbrella_app_path] do
      with_app app_path do
        {:ok, _} = File.rm_rf(Path.join(app_path, "_build"))
        _ = File.rm(Path.join(app_path, "mix.lock"))
        {:ok, _} = mix("deps.get")
        {:ok, _} = mix("compile")
      end
    end
    :ok
  end
  
  setup do
    for app_path <- [@standard_app_path, @umbrella_app_path] do
      with_app app_path do
        reset_changes!(app_path)
      end
    end
    :ok
  end
  
  @doc "Get the app path for the current integration test context"
  def app_path do
    Process.get(:app_path) || raise "app_path not set!"
  end
  
  @doc "Get the output path for the current integration test context"
  def output_path do
    Process.get(:output_path) || raise "output_path not set!"
  end
 
  @doc """
  Helper for applying an upgrade to standard app, from v1 to v2
  """
  def v1_to_v2 do
    config_path = Path.join([@standard_app_path, "config", "config.exs"])
    a_path = Path.join([@standard_app_path, "lib", "standard_app", "a.ex"])
    b_path = Path.join([@standard_app_path, "lib", "standard_app", "b.ex"])

    upgrade(@standard_app_path, "0.0.2", [
      {config_path, "num_procs: 2", "num_procs: 4"},
      {a_path, "{:ok, {1, []}}", "{:ok, {2, []}}"},
      {b_path, "loop({1, []}, parent, debug)", "loop({2, []}, parent, debug)"}
    ])
  end
  
  @doc """
  Reset all changes applied to the file at the given path
  """
  def reset!(path) do
    backup = path <> ".backup"
    if File.exists?(backup) do
      File.cp!(backup, path)
      File.rm!(backup)
    end
  end
  
  @doc """
  Reset all changes applied to files in the given application path
  """
  def reset_changes!(app_path) do
    app = Path.basename(app_path)
    changes =
      Path.join([app_path, "**", "*.backup"])
      |> Path.wildcard()
      |> Enum.map(&(Path.join(Path.dirname(&1), Path.basename(&1, ".backup"))))
    Enum.each(changes, &reset!/1)
    File.rm_rf!(Path.join([app_path, "rel", app]))
    File.rm_rf!(Path.join([app_path, "rel", "appups", app]))
    :ok
  end
  
  @doc """
  Apply a change to the file at the given path
  """
  def apply_change(path, match, replacement) do
    apply_changes(path, [{match, replacement}])
  end
  
  @doc """
  Apply one or more changes to the given path, where a change involves a string replacement of the contents of the file
  """
  def apply_changes(path, changes) when is_list(changes) do
    unless File.exists?(path <> ".backup") do
      File.cp!(path, path <> ".backup")
    end
    old = File.read!(path)
    new = 
      changes
      |> Enum.reduce(old, fn {match, replacement}, acc -> 
        String.replace(acc, match, replacement)
      end)
    File.write!(path, new)
  end
  
  @doc """
  Upgrades the application at the given path, to the given version, by applying the set of changes provided.
  """
  def upgrade(app_path, version, changes) do
    # Set new version in mix.exs
    mix_exs = Path.join([app_path, "mix.exs"])
    apply_change(mix_exs, ~r/(version: )"\d+.\d+.\d+"/, "\\1\"#{version}\"")
    # Set new version in release config
    rel_config_path = Path.join([app_path, "rel", "config.exs"])
    apply_change(rel_config_path, ~r/(version: )"\d+.\d+.\d+"/, "\\1\"#{version}\"")
    # Apply other changes for this upgrade
    for change <- changes do
      case change do
        {path, changeset} when is_list(changeset) ->
          apply_changes(path, changeset)
        {path, match, replacement} ->
          apply_change(path, match, replacement)
      end
    end
    :ok
  end
  
  @doc """
  Deploys a release tarball from the given release root directory + version, to the given target directory.
  It also extracts the tarball in the target directory.
  """
  def deploy_tarball(release_root_dir, version, directory) do
    dir = String.to_charlist(directory)
    tar = 
      case Path.wildcard(Path.join([release_root_dir, "releases", version, "*.tar.gz"])) do
        [tar] ->
          String.to_charlist(tar)
      end
    case :erl_tar.extract(tar, [{:cwd, dir}, :compressed]) do
      :ok ->
        :ok = Utils.write_term(Path.join(directory, "extra.config"), standard_app: [foo: :bar])
      other ->
        other
    end
  end
  
  @doc """
  Deploys an upgrade tarball from the given release root directory + version, to the given target directory
  """
  def deploy_upgrade_tarball(release_root_dir, version, directory) do
    target = Path.join([directory, "releases", version])
    File.mkdir_p!(Path.join([directory, "releases", version]))
    source = 
      case Path.wildcard(Path.join([release_root_dir, "releases", version, "*.tar.gz"])) do
        [source] ->
          source
      end
    name = Path.basename(source)
    File.cp!(source, Path.join(target, name))
  end
end
