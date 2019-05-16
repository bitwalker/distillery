defmodule Distillery.Releases.Checks.LoadedOrphanedApps do
  @moduledoc """
  This check determines whether or not any of the applications in the release
  satisfy all three of the following conditions:

    * Have a start type of `:load` or `:none`
    * Are not included by any other application in the release (orphaned)
    * Are expected to be started by at least one other application in the release,
      i.e. are present in the dependent application's `:applications` list.

  Such "loaded-orphaned" applications will result in a release which only partially boots,
  except in the rare case where the loaded applications are started before `:init` attempts
  to boot the dependents. If the loaded applications are _not_ started before this point, the
  application controller will wait indefinitely for the loaded applications to be started, which
  will never occur because the thing which might have started them isn't started itself yet.

  In general this should be very rare, but has occurred, and can be very difficult to troubleshoot.
  This check provides information on how to work around the case where this happens, but the solutions
  are one of the following:

    * Add these loaded applications, and their dependents, to included_applications in the releasing app.
      This requires that the releasing app take over the lifecycle of these applications, namely starting them
      during it's own start callback, generally by adding them to it's supervisor tree. Recommended only for
      those cases where it is absolutely required that the application be started at a particular point in time.
    * Remove the `:load` start type from the applications which are orphaned, effectively allowing them to be
      started by `:init` when needed. This does imply that the application will be started, rather than simply
      loaded, which may not be desired - in such cases you need to evaluate the dependent applications to see whether
      they truly need to have the dependency started, or if they can be modified and remove it from their applications list.
      If neither of those work, you will need to use included_applications.

  """
  use Distillery.Releases.Checks

  alias Distillery.Releases.Release
  alias Distillery.Releases.App

  def run(%Release{applications: apps}) do
    # Applications with start type :load or :none
    loaded =
      apps
      |> Enum.filter(fn %App{start_type: type} -> type in [:none, :load] end)
      |> Enum.map(fn %App{name: name} -> name end)
      |> MapSet.new()

    # Applications which are in some other application's :included_applications list
    included_apps =
      apps
      |> Enum.flat_map(fn %App{included_applications: ia} -> ia end)
      |> Enum.uniq()
      |> MapSet.new()

    # Applications which are in some other application's :applications list
    required_apps =
      apps
      |> Enum.flat_map(fn %App{applications: a} -> a end)
      |> Enum.uniq()
      |> MapSet.new()

    # Applications which have start type :load, but are not included applications
    loaded_not_included =
      loaded
      |> MapSet.difference(included_apps)

    # Applications which have start type :load, are not included,
    # but are in some other application's :applications list
    loaded_but_required =
      loaded_not_included
      |> MapSet.intersection(required_apps)

    # A list of applications which require the `loaded_but_required` apps
    requiring_apps =
      apps
      |> Enum.filter(fn %App{applications: a} ->
        required_loaded =
          a
          |> MapSet.new()
          |> MapSet.intersection(loaded_but_required)
          |> MapSet.to_list()

        required_loaded != []
      end)
      |> Enum.map(fn %App{name: a} -> a end)

    # A list of applications which either directly or transitively require
    # the applications which are loaded and required
    required_transitively = require_transitively(apps, requiring_apps)

    if Enum.empty?(loaded_but_required) do
      :ok
    else
      warning = """
      You have specified a start type of :load or :none for the following orphan applications:
      #{Enum.join(Enum.map(loaded_but_required, fn a -> "        #{inspect(a)}" end), "\n")}

      These applications are considered orphaned because they are not included by another
      application (i.e. present in the included_applications list). Since they are only loaded,
      neither the runtime, or any application is responsible for ensuring they are started.
      This is a problem because the following applications - either directly or transitively -
      depend on the above applications to be started before they can start; and this cannot
      be guaranteed:
      #{Enum.join(Enum.map(required_transitively, fn a -> "        #{inspect(a)}" end), "\n")}

      If you do not address this, your release may appear to start successfully, but may
      in fact only be partially started, which can manifest as portions of your application
      not working as expected. For example, a Phoenix endpoint not binding to it's configured port.
      You should either add all of these applications to :included_applications, and ensure
      they are started as part of your application; or you should change the start type of the
      first set of applications to :permanent or leave the start type unspecified. The latter
      is the best approach when possible.
      """

      {:ok, warning}
    end
  end

  defp require_transitively(all, requiring) do
    require_transitively(all, requiring, requiring)
  end

  defp require_transitively(_all, [], acc), do: acc

  defp require_transitively(all, [app | rest], acc) do
    requiring =
      all
      |> Enum.filter(fn %App{applications: a} -> Enum.member?(a, app) end)
      |> Enum.reject(fn %App{name: a} -> Enum.member?(acc, a) end)
      |> Enum.map(fn %App{name: a} -> a end)

    require_transitively(all, rest ++ requiring, acc ++ requiring)
  end
end
