defmodule Distillery.Releases.Plugin do
  @moduledoc """
  This module provides a simple way to add additional processing to
  phases of the release assembly and archival.

  ## Implementing your own plugin

  To create a Distillery plugin, create a new module in which you
  `use Distillery.Releases.Plugin`. Then write implementations for the following
  callbacks:

    - `c:before_assembly/2`
    - `c:after_assembly/2`
    - `c:before_package/2`
    - `c:after_package/2`
    - `c:after_cleanup/2`

  The default implementation is to pass the original `%Release{}`.
  You will only need to implement the functions your plugin requires.

  When you `use Distillery.Releases.Plugin`, the following happens:

    - Your module is marked with `@behaviour Distillery.Releases.Plugin`.
    - The `Distillery.Releases.Release` struct is aliased to `%Release{}`.
    - The functions `debug/1`, `info/1`, `warn/1`, `notice/1`, and `error/1`
      are imported from `Distillery.Releases.Shell`. These should be used to present
      output to the user.

  The first four callbacks (`c:before_assembly/2`, `c:after_assembly/2`,
  `c:before_package/2`, and `c:after_package/2`) will each be passed the
  `%Release{}` struct and options passed to the plugin. You can return a modified
  struct, or `nil`. Any other return value will lead to runtime errors.

  `c:after_cleanup/2` is only invoked on `mix distillery.release.clean`. It will be passed
  the command line arguments. The return value is not used.

  ## Example

      defmodule MyApp.PluginDemo do
        use Distillery.Releases.Plugin

        def before_assembly(%Release{} = release, _opts) do
          info "This is executed just prior to assembling the release"
          release # or nil
        end

        def after_assembly(%Release{} = release, _opts) do
          info "This is executed just after assembling, and just prior to packaging the release"
          release # or nil
        end

        def before_package(%Release{} = release, _opts) do
          info "This is executed just before packaging the release"
          release # or nil
        end

        def after_package(%Release{} = release, _opts) do
          info "This is executed just after packaging the release"
          release # or nil
        end

        def after_cleanup(_args, _opts) do
          info "This is executed just after running cleanup"
          :ok # It doesn't matter what we return here
        end
      end
  """

  alias Distillery.Releases.Release

  @doc """
  Called before assembling the release.

  Should return a modified `%Release{}` or `nil`.
  """
  @callback before_assembly(Release.t(), Keyword.t()) :: Release.t() | nil

  @doc """
  Called after assembling the release.

  Should return a modified `%Release{}` or `nil`.
  """
  @callback after_assembly(Release.t(), Keyword.t()) :: Release.t() | nil

  @doc """
  Called before packaging the release.

  Should return a modified `%Release{}` or `nil`.

  When in `dev_mode`, the packaging phase is skipped.
  """
  @callback before_package(Release.t(), Keyword.t()) :: Release.t() | nil

  @doc """
  Called after packaging the release.

  Should return a modified `%Release{}` or `nil`.

  When in `dev_mode`, the packaging phase is skipped.
  """
  @callback after_package(Release.t(), Keyword.t()) :: Release.t() | nil

  @doc """
  Called when the user invokes the `mix distillery.release.clean` task.

  The callback will be passed the command line arguments to `mix distillery.release.clean`.
  It should clean up the files the plugin created. The return value of this
  callback is ignored.
  """
  @callback after_cleanup([String.t()], Keyword.t()) :: any

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Distillery.Releases.Plugin
      alias Distillery.Releases.Shell
      alias Distillery.Releases.Release
      import Distillery.Releases.Shell, only: [debug: 1, info: 1, warn: 1, notice: 1, error: 1]

      Module.register_attribute(__MODULE__, :name, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :moduledoc, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :shortdoc, accumulate: false, persist: true)

      def before_assembly(release), do: release
      def after_assembly(release), do: release
      def before_package(release), do: release
      def after_package(release), do: release
      def after_cleanup(release, _), do: release

      defoverridable before_assembly: 1,
                     after_assembly: 1,
                     before_package: 1,
                     after_package: 1,
                     after_cleanup: 2
    end
  end

  @doc """
  Run the `c:before_assembly/2` callback of all plugins of `release`.
  """
  @spec before_assembly(Release.t()) :: {:ok, Release.t()} | {:error, term}
  def before_assembly(release), do: call(:before_assembly, release)

  @doc """
  Run the `c:after_assembly/2` callback of all plugins of `release`.
  """
  @spec after_assembly(Release.t()) :: {:ok, Release.t()} | {:error, term}
  def after_assembly(release), do: call(:after_assembly, release)

  @doc """
  Run the `c:before_package/2` callback of all plugins of `release`.
  """
  @spec before_package(Release.t()) :: {:ok, Release.t()} | {:error, term}
  def before_package(release), do: call(:before_package, release)

  @doc """
  Run the `c:after_package/2` callback of all plugins of `release`.
  """
  @spec after_package(Release.t()) :: {:ok, Release.t()} | {:error, term}
  def after_package(release), do: call(:after_package, release)

  @doc """
  Run the `c:after_cleanup/2` callback of all plugins of `release`.
  """
  @spec after_cleanup(Release.t(), [String.t()]) :: :ok | {:error, term}
  def after_cleanup(release, args), do: run(release.profile.plugins, :after_package, args)

  @spec call(atom(), Release.t()) :: {:ok, term} | {:error, {:plugin, term}}
  defp call(callback, release) do
    plugins =
      for p <- release.profile.plugins do
        case p do
          {_p, _opts} ->
            p

          mod when is_atom(mod) ->
            {mod, []}

          other ->
            throw({:error, {:plugin, {:invalid_plugin, other}}})
        end
      end

    call(plugins, callback, release)
  catch
    :throw, {:error, {:plugin, {kind, err}}} ->
      {:error, {:plugin, {kind, err, __STACKTRACE__}}}
  end

  defp call([], _, release), do: {:ok, release}

  defp call([{plugin, opts} | plugins], callback, release) do
    apply_plugin(plugin, callback, release, opts)
  rescue
    e ->
      {:error, {:plugin, {e, __STACKTRACE__}}}
  catch
    kind, err ->
      {:error, {:plugin, {kind, err, __STACKTRACE__}}}
  else
    nil ->
      call(plugins, callback, release)

    %Release{} = updated ->
      call(plugins, callback, updated)

    result ->
      {:error, {:plugin, {:plugin_failed, :bad_return_value, plugin, result}}}
  end

  # TODO: remove once the /1 plugins are deprecated
  defp apply_plugin(plugin, callback, release, opts) do
    if function_exported?(plugin, callback, 2) do
      apply(plugin, callback, [release, opts])
    else
      apply(plugin, callback, [release])
    end
  end

  @spec run([atom()], atom, [String.t()]) :: :ok | {:error, {:plugin, term}}
  defp run([], _, _), do: :ok

  defp run([{plugin, opts} | plugins], callback, args) do
    apply_plugin(plugin, callback, args, opts)
  rescue
    e ->
      {:error, {:plugin, {e, __STACKTRACE__}}}
  catch
    kind, err ->
      {:error, {:plugin, {kind, err, __STACKTRACE__}}}
  else
    _ ->
      run(plugins, callback, args)
  end
end
