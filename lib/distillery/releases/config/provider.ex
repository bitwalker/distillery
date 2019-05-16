defmodule Distillery.Releases.Config.Provider do
  @moduledoc """
  This defines the behaviour for custom configuration providers.
  """
  alias Distillery.Releases.Utils

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      alias unquote(__MODULE__)
    end
  end

  @doc """
  Called when the provider is initialized.

  Providers are invoked pre-boot, in a dedicated VM, with all application code loaded,
  and kernel, stdlib, compiler, and elixir applications started. Providers must use
  this callback to push configuration into the application environment, which will be
  persisted to a final `sys.config` for the release itself.

  The arguments given to `init/1` are the same as given in the `config_providers` setting in
  your release configuration file.
  """
  @callback init(args :: [term]) :: :ok | no_return

  @doc false
  def enabled?(providers, provider) when is_list(providers) and is_atom(provider) do
    Enum.any?(providers, fn
      mod when is_atom(mod) -> mod == provider
      {mod, _opts} when is_atom(mod) -> mod == provider
    end)
  end

  @doc false
  def init(providers) when is_list(providers) do
    for provider <- providers do
      try do
        case provider do
          p when is_atom(p) ->
            p.init([])

          {p, args} ->
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

    # Build up configuration
    env =
      for {app, _, _} <- :application.loaded_applications() do
        {app, :application.get_all_env(app)}
      end

    # Get config path
    config_path =
      case Keyword.get(:init.get_arguments(), :config, []) do
        [] ->
          Path.join(System.get_env("RELEASE_CONFIG_DIR") || "", "sys.config")

        [path] ->
          List.to_string(path)
      end

    # Persist sys.config
    case Utils.write_term(config_path, env) do
      :ok ->
        :ok

      {:error, {:write_terms, mod, reason}} ->
        print_err("Unable to write sys.config to #{config_path}: #{mod.format_error(reason)}")
        :erlang.halt(1)
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
