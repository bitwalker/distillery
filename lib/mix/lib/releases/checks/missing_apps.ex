defmodule Mix.Releases.Checks.MissingApps do
  @moduledoc """
  This check looks to see if there are direct or transitive dependencies
  which the releasing application requires at runtime, but which are missing
  from the release configuration.
  """
  use Mix.Releases.Checks

  alias Mix.Releases.Release
  alias Mix.Releases.App

  def run(%Release{applications: apps}) do
    # Accumulate all unhandled deps, and see if they are present in the list
    # of applications, if so they can be ignored, if not, warn about them
    unhandled =
      apps
      |> Enum.flat_map(fn %App{} = app -> app.unhandled_deps end)
      |> MapSet.new()

    handled =
      apps
      |> Enum.flat_map(fn %App{name: a} = app ->
        Enum.concat([a | app.applications], app.included_applications)
      end)
      |> Enum.uniq()
      |> MapSet.new()

    ignore_missing = Application.get_env(:distillery, :no_warn_missing, [])

    missing =
      unhandled
      |> MapSet.difference(handled)
      |> MapSet.to_list()

    warn_missing =
      case ignore_missing do
        false ->
          missing

        true ->
          []

        ignore ->
          Enum.reject(missing, &Enum.member?(ignore, &1))
      end

    case warn_missing do
      [] ->
        :ok

      _ ->
        warning = """
        One or more direct or transitive dependencies are missing from
            :applications or :included_applications, they will not be included
            in the release:

        #{Enum.join(Enum.map(warn_missing, fn a -> "        #{inspect(a)}" end), "\n")}

            This can cause your application to fail at runtime. If you are sure
            that this is not an issue, you may ignore this warning.
        """

        {:ok, warning}
    end
  end
end
