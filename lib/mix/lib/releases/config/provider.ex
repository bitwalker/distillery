defmodule Mix.Releases.Config.Provider do
  @moduledoc """
  This defines the behaviour for custom configuration providers.

  Keys supplied to providers are a list of atoms which represent the path of the
  configuration key, beginning with the application name:

      > MyProvider.get([:myapp, :server, :port])
      {:ok, 8080}

      > MyProvider.get([:myapp, :invalid, :key])
      nil


  The `init/1` function is called during startup, typically before any applications are running,
  with the exception of `:kernel`, `:stdlib`, `:elixir`, and `:compiler`. All application code will
  be loaded, but you may want to be explicit about it to ensure that this is true even in a relaxed
  code loading environment.

  The `init/1` function will receive the arguments it was provided in its definition.
  """

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def get([app | keypath]) do
        config = Application.get_all_env(app)
        case get_in(config, keypath) do
          nil ->
            nil
          v ->
            {:ok, v}
        end
      end

      defoverridable [get: 1]
    end
  end

  @doc """
  Called when the provider is initialized
  """
  @callback init(args :: [term]) :: :ok | no_return

  @doc """
  Called when the provider is being asked to supply a value for the given key
  """
  @callback get(key :: [atom]) :: {:ok, term} | nil

  @doc false
  def enabled?(providers, provider) when is_list(providers) and is_atom(provider) do
    Enum.any?(providers, fn
      mod when is_atom(mod) -> mod == provider
      {mod, _opts} when is_atom(mod) -> mod == provider
    end)
  end

  @doc false
  def init(providers) when is_list(providers) do
    # If called later, reset the table
    case :ets.info(__MODULE__, :size) do
      :undefined ->
        :ets.new(__MODULE__, [:public, :set, :named_table])

      _ ->
        :ets.delete_all_objects(__MODULE__)
    end

    for provider <- providers do
      case provider do
        p when is_atom(p) ->
          :ets.insert(__MODULE__, {p, []})
          p.init([])

        {p, args} ->
          :ets.insert(__MODULE__, provider)
          p.init(args)

        p ->
          raise ArgumentError,
            message:
              "Invalid #{__MODULE__}: Expected module or `{module, args}` tuple, got #{inspect(p)}"
      end
    end
  end

  @doc false
  def get(key) do
    get(:ets.tab2list(__MODULE__), key)
  end

  defp get([], _key), do: nil

  defp get([provider | providers], key) do
    case provider.get(key) do
      nil ->
        get(providers, key)

      {:ok, _} = val ->
        val
    end
  end
end
