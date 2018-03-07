defmodule Mix.Releases.Config.Providers.Elixir do
  @moduledoc """
  Provides loading of Elixir's `config.exs` config file.
  """

  use Mix.Releases.Config.Provider

  @impl Mix.Releases.Config.Provider
  def init([path]) do
    path
    |> Mix.Config.read!()
    |> Mix.Config.persist()
  end

  @impl Mix.Releases.Config.Provider
  def get([app | rest]) do
    app
    |> Application.get_all_env
    |> get_in(rest)
  end

  @doc """
  Given a path to a config file, this function will return the quoted AST of
  that config and all configs that it imports.
  """
  def read_quoted!(file) do
    {quoted, _} = do_read_quoted!(file, [])
    quoted
  end

  defp do_read_quoted!(file, loaded_paths) do
    try do
      file = Path.expand(file)
      if file in loaded_paths do
        raise ArgumentError, message: "recursive load of #{file} detected"
      end

      content = File.read!(file)
      quoted = Code.string_to_quoted!(content, file: file, line: 1)
      merged = merge_imports(quoted, [], file, [file | loaded_paths])

      {merged, loaded_paths}
    rescue
      e in [Mix.Config.LoadError] -> reraise(e, System.stacktrace)
      e -> reraise(Mix.Config.LoadError, [file: file, error: e], System.stacktrace)
    end
  end

  defp merge_imports({:__block__, _, block}, acc, file, loaded_paths) do
    merge_imports(block, acc, file, loaded_paths)
  end
  defp merge_imports([], acc, _file, _loaded_paths) do
    {:__block__, [], Enum.reverse(acc)}
  end
  defp merge_imports([{:import_config, _, [path]} | block], acc, file, loaded_paths) when is_binary(path) do
    path = Path.join(Path.dirname(file), Path.relative_to(path, file))
    {{:__block__, _, quoted}, new_loaded_paths} = do_read_quoted!(path, loaded_paths)
    new_acc =
      quoted
      |> Enum.reject(fn {:use, _, [{:__aliases__, _, [:Mix, :Config]}]} -> true; _ -> false end)
      |> Enum.reverse
      |> Enum.concat(acc)
    merge_imports(block, new_acc, file, new_loaded_paths)
  end
    case eval_path(path_expr) do
  defp merge_imports([{:import_config, _, [path_expr]} = item | block], acc, file, loaded_paths) do
      nil ->
        err = "Invalid use of import_config. Only static paths and interpolation with Mix.env are allowed\n" <>
          "  Expected: import_config \"path/to/config.exs\" # or \"path/to/\#{Mix.env}.exs\"\n" <>
          "  Got: #{Macro.to_string(item)}"
        raise Mix.Config.LoadError, [file: file, error: err]
      path ->
        path = Path.join(Path.dirname(file), Path.relative_to(path, file))
        {{:__block__, _, quoted}, new_loaded_paths} = do_read_quoted!(path, loaded_paths)
        new_acc =
          quoted
          |> Enum.reject(fn {:use, _, [{:__aliases__, _, [:Mix, :Config]}]} -> true; _ -> false end)
          |> Enum.reverse
          |> Enum.concat(acc)
        merge_imports(block, new_acc, file, new_loaded_paths)
    end
  end
  defp merge_imports([other | block], acc, file, loaded_paths) do
    merge_imports(block, [other | acc], file, loaded_paths)
  end

  defp eval_path(path) when is_binary(path) do
    path
  end
  defp eval_path(expr) do
    try do
      {path, _bindings} = Code.eval_quoted(expr)
      path
    catch
      _, _ ->
        :error
    end
  end

end
