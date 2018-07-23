defmodule Mix.Releases.Config.Provider do
  @moduledoc """
  This defines the behaviour for custom configuration providers.
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
  Called when the provider is initialized.

  This function is called early during the boot sequence, after all applications are loaded,
  but only `:kernel`, `:stdlib`, `:compiler`, and `:elixir` are started. This means that you
  cannot expect supervisors and processes to be running. You may need to start them manually,
  or start entire applications manually, but it is critical that you stop them before returning
  from `init/1`, or the boot sequence will fail post-configuration.
  
  The arguments given to `init/1` are the same as given in the `config_providers` setting in
  your release configuration file.
  
  NOTE: It is recommended that you use `init/1` to load configuration and then
  persist it into the application environment, e.g. with
  `Application.put_env/3`. This ensures that applications need not be aware of
  your specific configuration provider.
  
  """
  @callback init(args :: [term]) :: :ok | no_return

  @doc """
  Called when the provider is being asked to supply a value for the given key
  
  Keys supplied to providers are a list of atoms which represent the path of the
  configuration key, beginning with the application name:
  
  NOTE: This is currently unused, but provides an API for fetching config values
  from specific providers, which may come in handy down the road. A default implementation
  is provided for you, which fetches values from the application environment.
  
  ## Examples

      > MyProvider.get([:myapp, :server, :port])
      {:ok, 8080}
      
      > MyProvider.get([:maypp, :invalid, :key])
      nil

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

  defp get([{provider, _args} | providers], key) do
    case provider.get(key) do
      nil ->
        get(providers, key)

      {:ok, _} = val ->
        val
    end
  end
end
