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
        vsn = '#{Keyword.get(spec, :vsn)}'
        apps = Keyword.get(spec, :applications, [])
        included = Keyword.get(spec, :included_applications, [])
        path = Application.app_dir(name)
        %__MODULE__{name: name, vsn: vsn,
                    applications: apps,
                    included_applications: included,
                    path: path}
    end
  end
  def new(name, start_type), do: {:error, "Invalid start type for #{name}: #{start_type}"}
end
