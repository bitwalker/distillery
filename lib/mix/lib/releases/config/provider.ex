defmodule Mix.Releases.Config.Provider do
  @moduledoc """
  This defines the behaviour for custom configuration providers.
  """

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      alias unquote(__MODULE__)

      def get([app | keypath]) do
        config = Application.get_all_env(app)

        case get_in(config, keypath) do
          nil ->
            nil

          v ->
            {:ok, v}
        end
      end

      defoverridable get: 1
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
      try do
        case provider do
          p when is_atom(p) ->
            :ets.insert(__MODULE__, {p, []})
            p.init([])

          {p, args} ->
            :ets.insert(__MODULE__, provider)
            p.init(args)

          p ->
            raise ArgumentError,
              msg:
                "Invalid #{__MODULE__}: " <>
                  "Expected module or `{module, args}` tuple, got #{inspect(p)}"
        end
      rescue
        err ->
          trace = System.stacktrace()
          msg = Exception.message(err) <> "\n" <> Exception.format_stacktrace(trace)
          print_err(msg)
          reraise err, trace
      catch
        kind, err ->
          print_err(Exception.format(kind, err, System.stacktrace()))

          case kind do
            :throw ->
              throw(err)

            :exit ->
              exit(err)

            :error ->
              :erlang.error(err)
          end
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

  @doc """
  Given a file path, this function expands it to an absolute path,
  while also expanding any environment variable references in the
  path.

  ## Examples

      iex> var = String.replace("#{__MODULE__}", ".", "_")
      ...> System.put_env(var, "hello")
      ...> {:ok, "var/hello/test"} = #{__MODULE__}.expand_path("var/${" <> var <> "}/test")
      
      iex> {:ok, "/" <> _} = #{__MODULE__}.expand_path("~/")
      
      iex> {:error, :unclosed_var_expansion} = #{__MODULE__}.expand_path("var/${FOO/test")

  """
  def expand_path(path) when is_binary(path) do
    case expand_path(path, <<>>) do
      {:ok, p} ->
        {:ok, Path.expand(p)}

      {:error, _} = err ->
        err
    end
  end

  defp expand_path(<<>>, acc),
    do: {:ok, acc}

  defp expand_path(<<?$, ?\{, rest::binary>>, acc) do
    case expand_var(rest) do
      {:ok, var, rest} ->
        expand_path(rest, acc <> var)

      {:error, _} = err ->
        err
    end
  end

  defp expand_path(<<c::utf8, rest::binary>>, acc) do
    expand_path(rest, <<acc::binary, c::utf8>>)
  end

  defp expand_var(bin),
    do: expand_var(bin, <<>>)

  defp expand_var(<<>>, _acc),
    do: {:error, :unclosed_var_expansion}

  defp expand_var(<<?\}, rest::binary>>, acc),
    do: {:ok, System.get_env(acc) || "", rest}

  defp expand_var(<<c::utf8, rest::binary>>, acc) do
    expand_var(rest, <<acc::binary, c::utf8>>)
  end

  defp print_err(msg) when is_binary(msg) do
    if IO.ANSI.enabled?() do
      IO.puts(IO.ANSI.format([IO.ANSI.red(), msg, IO.ANSI.reset()]))
    else
      IO.puts(msg)
    end
  end
end
