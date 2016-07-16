defmodule Mix.Releases.Environment do
  @moduledoc """
  Represents a unique configuration for releases built
  in this environment.
  """
  alias Mix.Releases.Profile

  defstruct name: :default,
            profile: %Profile{}

  def new(name) do
    %__MODULE__{name: name}
  end
end
