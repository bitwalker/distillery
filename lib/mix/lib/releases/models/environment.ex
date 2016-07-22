defmodule Mix.Releases.Environment do
  @moduledoc """
  Represents a unique configuration for releases built
  in this environment.
  """
  alias Mix.Releases.Profile

  defstruct name: :default,
            profile: %Profile{}

  @type t :: %__MODULE__{
    name: atom(),
    profile: Profile.t
  }

  @doc """
  Creates a new Environment with the given name
  """
  @spec new(atom()) :: __MODULE__.t
  def new(name) do
    %__MODULE__{name: name}
  end
end
