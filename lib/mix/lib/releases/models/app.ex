defmodule Mix.Releases.App do
  @moduledoc """
  Represents important metadata about a given application.
  """

  defstruct name: nil,
            vsn: nil,
            applications: [],
            included_applications: [],
            unhandled_deps: [],
            start_type: nil,
            path: nil

  @type start_type :: :permanent | :temporary | :transient | :load | :none
  @type t :: %__MODULE__{
          name: atom(),
          vsn: String.t(),
          applications: [atom()],
          included_applications: [atom()],
          unhandled_deps: [atom()],
          start_type: start_type,
          path: nil | String.t()
        }

  @valid_start_types [:permanent, :temporary, :transient, :load, :none]
  @new_start_types [nil | @valid_start_types]

  @doc """
  Create a new Application struct from an application name
  """
  @spec new(atom, [Mix.Dep.t()]) :: nil | __MODULE__.t() | {:error, String.t()}
  def new(name, loaded_deps), do: new(name, nil, loaded_deps)

  @doc """
  Same as new/1, but specify the application's start type
  """
  @spec new(atom, start_type | nil, [Mix.Dep.t()]) :: nil | __MODULE__.t() | {:error, String.t()}
  def new(name, start_type, loaded_deps) when is_atom(name) and start_type in @new_start_types do
    dep =
      Enum.find(loaded_deps, fn
        %Mix.Dep{app: ^name} -> true
        _ -> false
      end)

    cond do
      is_nil(dep) ->
        do_new(name, start_type, loaded_deps)

      name == :distillery ->
        do_new(name, start_type, loaded_deps)

      Keyword.get(dep.opts, :runtime) === false ->
        nil

      :else ->
        do_new(name, start_type, loaded_deps)
    end
  end

  def new(name, start_type, _loaded_deps),
    do: {:error, {:apps, {:invalid_start_type, name, start_type}}}

  defp do_new(name, start_type, loaded_deps) do
    _ = Application.load(name)

    case Application.spec(name) do
      nil ->
        nil

      spec ->
        vsn = '#{Keyword.get(spec, :vsn)}'
        deps = get_dependencies(name, loaded_deps)
        apps = Keyword.get(spec, :applications, [])
        included = Keyword.get(spec, :included_applications, [])
        path = Application.app_dir(name)

        missing =
          MapSet.new(deps)
          |> MapSet.difference(MapSet.union(MapSet.new(apps), MapSet.new(included)))
          |> MapSet.to_list()

        %__MODULE__{
          name: name,
          vsn: vsn,
          start_type: start_type,
          applications: apps,
          included_applications: included,
          unhandled_deps: missing,
          path: path
        }
    end
  end

  @doc """
  Determines if the provided start type is a valid one.
  """
  @spec valid_start_type?(atom) :: boolean()
  def valid_start_type?(start_type) when start_type in @valid_start_types, do: true

  def valid_start_type?(_), do: false

  Code.ensure_loaded(Mix.Dep)

  if function_exported?(Mix.Dep, :filter_by_name, 3) do
    defp loaded_by_name(name, deps, opts),
      do: Mix.Dep.filter_by_name([name], deps, opts)
  else
    defp loaded_by_name(name, deps, opts),
      do: Mix.Dep.loaded_by_name([name], deps, opts)
  end

  # Gets a list of all applications which are children
  # of this application.
  defp get_dependencies(name, loaded_deps) do
    loaded_by_name(name, loaded_deps, [])
    |> Stream.flat_map(fn %Mix.Dep{deps: deps} -> deps end)
    |> Stream.filter(&include_dep?/1)
    |> Enum.map(&map_dep/1)
  rescue
    # This is a top-level app
    Mix.Error ->
      cond do
        Mix.Project.umbrella?() ->
          # find the app in the umbrella
          app_path = Path.join(Mix.Project.config()[:apps_path], "#{name}")

          cond do
            File.exists?(app_path) ->
              Mix.Project.in_project(name, app_path, fn mixfile ->
                mixfile.project[:deps]
                |> Stream.filter(&include_dep?/1)
                |> Enum.map(&map_dep/1)
              end)

            :else ->
              []
          end

        :else ->
          Mix.Project.config()[:deps]
          |> Stream.filter(&include_dep?/1)
          |> Enum.map(&map_dep/1)
      end
  end

  defp include_dep?({_, _}), do: true
  defp include_dep?({:distillery, _, _}), do: true
  defp include_dep?({_, _, opts}), do: include_dep?(opts)
  defp include_dep?(%Mix.Dep{app: :distillery}), do: true
  defp include_dep?(%Mix.Dep{opts: opts}), do: include_dep?(opts)

  defp include_dep?(opts) when is_list(opts) do
    if Keyword.get(opts, :runtime) == false do
      false
    else
      case Keyword.get(opts, :only) do
        nil -> true
        envs when is_list(envs) -> Enum.member?(envs, :prod)
        env when is_atom(env) -> env == :prod
      end
    end
  end

  defp map_dep({a, _}), do: a
  defp map_dep({a, _, _opts}), do: a
  defp map_dep(%Mix.Dep{app: a}), do: a
end
