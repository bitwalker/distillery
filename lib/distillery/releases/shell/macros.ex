defmodule Distillery.Releases.Shell.Macros do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      # Used for mapping levels to a total order
      @levelid 0
      @levels %{}
      @colors %{}
      @prefixes %{}

      @before_compile unquote(__MODULE__)

      import unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc "Returns the current verbosity setting"
      def verbosity(),
        do: Application.get_env(:mix, :release_logger_verbosity, :normal)

      @doc "Print a message formatted with the default formatting for the given log level"
      def levelf(level, message) do
        # Applies level-specific formatting generically, taking verbosity into account
        # If the verbosity is such that no message should be produced, empty iodata is the result
        color = level_to_color(level)

        data =
          verbosityf(level, Distillery.Releases.Shell.colorf([level_to_prefix(level), message], color))

        IO.write(data)
      end

      # Filter a message by log level and verbosity, returning iodata to write
      defp verbosityf(level, message) do
        vlevel = verbosity_to_level(verbosity())

        if gte(level, vlevel) do
          message
        else
          []
        end
      end

      @inverted_levels @levels |> Enum.map(fn {k, v} -> {v, k} end) |> Map.new()
      @verbose_level Map.fetch!(@inverted_levels, 1)
      @normal_level Map.fetch!(@inverted_levels, 2)
      @quiet_level Map.get(
                     @inverted_levels,
                     Map.get(@levels, :notice),
                     Map.fetch!(@inverted_levels, 3)
                   )
      defp verbosity_to_level(:verbose), do: @verbose_level
      defp verbosity_to_level(:normal), do: @normal_level
      defp verbosity_to_level(:quiet), do: @quiet_level
      defp verbosity_to_level(:silent), do: :suppress_all

      # Map log levels to a default prefix
      defp level_to_prefix(level) do
        Map.get(@prefixes, level, "")
      end

      # Map log levels to a default color
      defp level_to_color(level) do
        Map.get(@colors, level, :normal)
      end

      # Compare log levels
      defp gte(a, :suppress_all),
        do: false

      defp gte(a, b),
        do: Map.get(@levels, a) >= Map.get(@levels, b)
    end
  end

  @doc """
  Generates the logging function for a specific log level
  """
  defmacro deflevel(name, opts \\ []) do
    error =
      case Keyword.get(opts, :error) do
        nil ->
          false

        val ->
          val
      end

    prefix = Keyword.get(opts, :prefix, "")
    color = Keyword.get(opts, :color, :normal)

    quote location: :keep do
      @levelid @levelid + 1
      @levels Map.put(@levels, unquote(name), @levelid)
      @prefixes Map.put(@prefixes, unquote(name), unquote(prefix))
      @colors Map.put(@colors, unquote(name), unquote(color))
      @doc """
      Write an #{unquote(name)} message to standard out.
      """
      if unquote(error) == false do
        def unquote(name)(message) do
          Distillery.Releases.Shell.levelf(unquote(name), [message, ?\n])
        end
      else
        def unquote(name)(message) do
          if Application.get_env(:distillery, unquote(error), false) do
            Distillery.Releases.Shell.fail!([message, ?\n])
          else
            Distillery.Releases.Shell.levelf(unquote(name), [message, ?\n])
          end
        end
      end
    end
  end
end
