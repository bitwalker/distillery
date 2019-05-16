defmodule Distillery.Releases.App do
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
          vsn: String.t(),
          applications: [atom()],
          included_applications: [atom()],
          start_type: start_type,
          path: nil | String.t()
        }

  @valid_start_types [:permanent, :temporary, :transient, :load, :none]

  @doc """
  Create a new Application struct from an application name
  """
  @spec new(atom) :: nil | __MODULE__.t() | {:error, String.t()}
  def new(name),
    do: do_new(name, nil)

  @doc """
  Same as new/1, but specify the application's start type
  """
  @spec new(atom, start_type | nil) :: nil | __MODULE__.t() | {:error, String.t()}
  def new(name, start_type) when is_atom(name) and start_type in @valid_start_types,
    do: do_new(name, start_type)

  def new(name, nil) when is_atom(name),
    do: do_new(name, nil)

  def new(name, start_type) do
    {:error, {:apps, {:invalid_start_type, name, start_type}}}
  end

  defp do_new(name, start_type) do
    _ = Application.load(name)

    case Application.spec(name) do
      nil ->
        nil

      spec ->
        vsn = '#{Keyword.get(spec, :vsn)}'
        apps = Keyword.get(spec, :applications, [])
        included = Keyword.get(spec, :included_applications, [])
        path = Application.app_dir(name)

        %__MODULE__{
          name: name,
          vsn: vsn,
          start_type: start_type,
          applications: apps,
          included_applications: included,
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
end
