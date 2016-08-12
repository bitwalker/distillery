defmodule Mix.Releases.App do
  @moduledoc """
  Represents important metadata about a given application.
  """
  defstruct name: nil,
    vsn: nil,
    applications: [],
    included_applications: [],
    start_type: nil,
    path: nil

  @type start_type :: :permanent | :temporary | :transient | :load | :none
  @type t :: %__MODULE__{
    name: atom(),
    vsn: String.t,
    applications: [atom()],
    included_applications: [atom()],
    start_type: start_type,
    path: nil | String.t
  }

  @doc """
  Create a new Application struct from an application name
  """
  @spec new(atom) :: nil | __MODULE__.t | {:error, String.t}
  def new(name), do: new(name, nil)

  @doc """
  Same as new/1, but specify the application's start type
  """
  @spec new(atom, start_type | nil) :: nil | __MODULE__.t | {:error, String.t}
  def new(name, start_type)
    when is_atom(name) and start_type in [nil, :permanent, :temporary, :transient, :load, :none] do
    _ = Application.load(name)
    case Application.spec(name) do
      nil -> nil
      spec ->
        vsn      = '#{Keyword.get(spec, :vsn)}'
        deps     = get_children(name)
        apps     = Enum.uniq(deps ++ Keyword.get(spec, :applications, []))
        included = Keyword.get(spec, :included_applications, [])
        path     = Application.app_dir(name)
        %__MODULE__{name: name, vsn: vsn,
                    applications: apps,
                    included_applications: included,
                    path: path}
    end
  end
  def new(name, start_type), do: {:error, "Invalid start type for #{name}: #{start_type}"}

  # Gets a list of all applications which are children
  # of this application.
  defp get_children(name) do
    try do
      Mix.Dep.loaded_by_name([name], [])
      |> Enum.flat_map(fn %Mix.Dep{deps: deps} -> deps end)
      |> Enum.map(fn %Mix.Dep{app: n} -> {n, :load} end)
    rescue
      Mix.Error -> # This is a top-level app
        cond do
          Mix.Project.umbrella? ->
            # find the app in the umbrella
            app_path = Path.join(Mix.Project.config[:apps_path], "#{name}")
            cond do
              File.exists?(app_path) ->
                Mix.Project.in_project(name, app_path, fn mixfile ->
                  mixfile.project[:deps]
                  |> Enum.map(fn {a, _} -> {a, :load} end)
                end)
              :else ->
                []
            end
          :else ->
            Mix.Project.config[:deps]
            |> Enum.map(fn {a, _} -> {a, :load} end)
        end
    end
  end
end
