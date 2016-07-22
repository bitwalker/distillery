defmodule Mix.Releases.Plugin do
  @moduledoc """
  This module provides a simple way to add additional processing to
  phases of the release assembly and archival.

  You can define your own plugins using the sample definition below. Note that

      defmodule MyApp.PluginDemo do
        use Mix.Releases.Plugin

        def before_assembly(%Release{} = release) do
          info "This is executed just prior to assembling the release"
        end

        def after_assembly(%Release{} = release) do
          info "This is executed just after assembling, and just prior to packaging the release"
        end

        def after_package(%Release{} = release) do
          info "This is executed just after packaging the release"
        end

        def after_cleanup(_args) do
          info "This is executed just after running cleanup"
        end
      end

  A couple things are imported or aliased for you. Those things are:

    - The `Mix.Releases.Release` struct is aliased for you to just Release
    - `debug/1`, `info/1`, `warn/1`, `notice/1`, and `error/1` are imported for you.
      These should be used to do any output for the user.

  `before_assembly/1` and `after_assembly/1` will each be passed a `Release` struct,
  containing the configuration for the release task, after the environment configuration
  has been merged into it. You can choose to return the struct modified or unmodified, or not at all.
  In the former case, any modifications you made will be passed on to the remaining plugins and then
  used during assembly/archival.
  The required callback `after_cleanup/1` is passed the command line arguments. The return value is not used.
  """
  use Behaviour
  alias Mix.Releases.Release

  @callback before_assembly(Release.t) :: any
  @callback after_assembly(Release.t) :: any
  @callback after_package(Release.t) :: any
  @callback after_cleanup([String.t]) :: any

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Mix.Releases.Plugin
      alias  Mix.Releases.Release
      alias  Mix.Releases.Logger
      import Mix.Releases.Logger, only: [debug: 1, info: 1, warn: 1, notice: 1, error: 1]

      Module.register_attribute __MODULE__, :name, accumulate: false, persist: true
      Module.register_attribute __MODULE__, :moduledoc, accumulate: false, persist: true
      Module.register_attribute __MODULE__, :shortdoc, accumulate: false, persist: true
    end
  end

  @doc """
  Runs before_assembly with all plugins.
  """
  @spec before_assembly(Release.t) :: {:ok, Release.t} | {:error, term}
  def before_assembly(release), do: call(:before_assembly, release)
  @doc """
  Runs after_assembly with all plugins.
  """
  @spec after_assembly(Release.t) :: {:ok, Release.t} | {:error, term}
  def after_assembly(release),  do: call(:after_assembly, release)
  @doc """
  Runs before_package with all plugins.
  """
  @spec before_package(Release.t) :: {:ok, Release.t} | {:error, term}
  def before_package(release),  do: call(:before_package, release)
  @doc """
  Runs after_package with all plugins.
  """
  @spec after_package(Release.t) :: {:ok, Release.t} | {:error, term}
  def after_package(release),   do: call(:after_package, release)
  @doc """
  Runs after_cleanup with all plugins.
  """
  @spec after_cleanup(Release.t, [String.t]) :: :ok | {:error, term}
  def after_cleanup(release, args), do: run(release.profile.plugins, :after_package, args)

  @spec call(atom(), Release.t) :: {:ok, term} | {:error, {:plugin_failed, term}}
  defp call(callback, release) do
    call(release.profile.plugins, callback, release)
  end
  defp call([], _, release), do: {:ok, release}
  defp call([plugin|plugins], callback, release) do
    try do
      case apply(plugin, callback, [release]) do
        nil ->
          call(plugins, callback, release)
        %Release{} = updated ->
          call(plugins, callback, updated)
        result ->
          {:error, {:plugin_failed, :bad_return_value, result}}
      end
    rescue
      e ->
        {:error, Exception.message(e)}
    end
  end

  @spec run([atom()], atom, [String.t]) :: :ok | {:error, {:plugin_failed, term}}
  defp run([], _, _), do: :ok
  defp run([plugin|plugins], callback, args) do
    try do
      apply(plugin, callback, [args])
      run(plugins, callback, args)
    rescue
      e ->
        {:error, Exception.message(e)}
    end
  end
end
