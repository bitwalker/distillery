defmodule Distillery.Releases.Checks.Erts do
  @moduledoc """
  Validates the ERTS configuration for the given release
  """
  use Distillery.Releases.Checks

  alias Distillery.Releases.Release
  alias Distillery.Releases.Profile
  alias Distillery.Releases.Utils

  def run(%Release{profile: %Profile{dev_mode: dev_mode, include_erts: include_erts}}) do
    with :ok <- Utils.validate_erts(include_erts) do
      # Warn if not including ERTS when not obviously running in a dev configuration
      if dev_mode == false and include_erts == false do
        {:ok,
         "IMPORTANT: You have opted to *not* include the Erlang runtime system (ERTS).\n" <>
           "You must ensure that the version of Erlang this release is built with matches\n" <>
           "the version the release will be run with once deployed. It will fail to run otherwise."}
      else
        :ok
      end
    end
  end
end
