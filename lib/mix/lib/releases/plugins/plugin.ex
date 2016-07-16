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

  @callback before_assembly(Mix.Releases.Release.t) :: any
  @callback after_assembly(Mix.Releases.Release.t) :: any
  @callback after_package(Mix.Releases.Release.t) :: any
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
  Loads all plugins in all code paths.
  """
  @spec load_all() :: [] | [atom]
  def load_all, do: get_plugins(Mix.Releases.Plugin)

  # Loads all modules that extend a given module in the current code path.
  #
  # The convention is that it will fetch modules with the same root namespace,
  # and that are suffixed with the name of the module they are extending.
  @spec get_plugins(atom) :: [] | [atom]
  defp get_plugins(plugin_type) when is_atom(plugin_type) do
    available_modules(plugin_type) |> Enum.reduce([], &load_plugin/2)
  end

  defp load_plugin(module, modules) do
    if Code.ensure_loaded?(module), do: [module | modules], else: modules
  end

  defp available_modules(plugin_type) do
    # Ensure the current projects code path is loaded
    Mix.Task.run("loadpaths", [])
    # Fetch all .beam files
    Path.wildcard(Path.join([Mix.Project.build_path, "lib/**/ebin/**/*.beam"]))
    |> Stream.map(&String.to_char_list/1)
    # Parse the BEAM for behaviour implementations
    |> Stream.map(fn path ->
      case :beam_lib.chunks(path, [:attributes]) do
        {:ok, {mod, [attributes: attrs]}}  ->
          {mod, Keyword.get(attrs, :behaviour)}
        _ ->
          :error
      end
    end)
    # Filter out behaviours we don't care about and duplicates
    |> Stream.filter(fn
      :error -> false
      {_mod, behaviours} -> is_list(behaviours) && plugin_type in behaviours
    end)
    |> Enum.map(fn {module, _} -> module end)
    |> Enum.uniq
  end
end
