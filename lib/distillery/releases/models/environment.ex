defmodule Distillery.Releases.Environment do
  @moduledoc """
  Represents a unique configuration for releases built in this environment.
  """
  alias Distillery.Releases.Profile

  defstruct name: :default,
            profile: nil

  @type t :: %__MODULE__{
          name: atom(),
          profile: Profile.t()
        }

  @doc """
  Creates a new Environment with the given name
  """
  @spec new(atom()) :: t()
  def new(name) when is_atom(name),
    do: %__MODULE__{name: name, profile: %Profile{}}
end
