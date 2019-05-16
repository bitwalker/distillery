defmodule Distillery.Releases.Checks do
  @moduledoc """
  This module defines a behavior for, and orchestrator of, static analysis checks
  to be performed at release-time. These checks are intended to operate on the fully
  reified release configuration and metadata, and return warnings, errors, or ok for
  the release assembler to react to.

  In most cases, warnings will be printed but assembly will continue; errors will be
  printed but will terminate assembly, and a successful check will be printed only if
  verbose logging is enabled.
  """
  alias Distillery.Releases.Release

  @callback run(Release.t()) :: :ok | {:ok, warning :: String.t()} | {:error, term}

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      alias unquote(__MODULE__)
    end
  end

  @type warning :: String.t()

  # The default set of checks to run when executing validate_configuration/1
  @default_checks [
    __MODULE__.Erts,
    __MODULE__.Cookie,
    __MODULE__.LoadedOrphanedApps
  ]

  @doc """
  Returns a list of all checks available to be applied.
  """
  def list() do
    extra = Application.get_env(:distillery, :extra_checks, [])
    Enum.concat(@default_checks, extra)
  end

  @doc """
  Runs all default and configured checks against the given release.
  """
  @spec run(Release.t()) :: :ok | {:error, term}
  def run(%Release{} = release) do
    Distillery.Releases.Shell.debug("Running validation checks..")
    run(list(), release)
  end

  @doc """
  Runs all of the given checks, in the given order.
  """
  @spec run([module], Release.t()) :: :ok | {:error, term}
  def run([], _release),
    do: :ok

  def run(checks, release),
    do: do_run(checks, release, [])

  defp do_run([], _release, warnings) do
    for warning <- Enum.reverse(warnings) do
      Distillery.Releases.Shell.notice(warning)
    end

    :ok
  end

  defp do_run([check | checks], %Release{} = release, warnings) do
    Distillery.Releases.Shell.debugf("    > #{Enum.join(Module.split(check), ".")}")

    case check.run(release) do
      :ok ->
        Distillery.Releases.Shell.debugf(" * PASS\n", :green)
        do_run(checks, release, warnings)

      {:ok, warning} when is_binary(warning) ->
        Distillery.Releases.Shell.debugf(" * WARN\n\n", :yellow)
        do_run(checks, release, [warning | warnings])

      {:error, _} = err ->
        Distillery.Releases.Shell.debugf(" * FAILED\n", :red)

        for warning <- Enum.reverse(warnings) do
          Distillery.Releases.Shell.notice(warning)
        end

        err

      other ->
        {:error,
         "The check #{__MODULE__} returned #{inspect(other)} " <>
           "when :ok, {:ok, String.t}, or {:error term} were expected"}
    end
  end
end
