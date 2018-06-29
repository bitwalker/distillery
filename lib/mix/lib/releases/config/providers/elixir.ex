defmodule Mix.Releases.Config.Providers.Elixir do
  @moduledoc """
  Provides loading of Elixir's `config.exs` config file.
  """

  use Mix.Releases.Config.Provider

  alias Mix.Releases.Logger

  @impl Mix.Releases.Config.Provider
  def init([path]) do
    if File.exists?(path) do
      path
      |> Mix.Config.read!()
      |> Mix.Config.persist()
    else
      :ok
    end
  end

  @impl Mix.Releases.Config.Provider
  def get([app | rest]) do
    app
    |> Application.get_all_env()
    |> get_in(rest)
  end

  @doc """
  Given a path to a config file, this function will return the quoted AST of
  that config and all configs that it imports.
  """
  def read_quoted!(file) do
    if String.contains?(file, "*") do
      {quoted, _} = do_read_quoted_wildcard!(file, [])
      quoted
    else
      {quoted, _} = do_read_quoted!(file, [])
      quoted
    end
  end
  
  defp do_read_quoted_wildcard!(path, loaded_paths) do
    # This has a wildcard path, so we need to walk the list
    # of files, and strip the `use Mix.Config` from all but the first,
    # and merge all of the quoted contents of those files
    {final_quoted, new_loaded_paths} =
      path
      |> Path.wildcard()
      |> Enum.reduce({nil, loaded_paths}, fn
        f, {nil, loaded_paths} ->
          # Extract the quoted body of the top-level block for merging
          {{:__block__, _, quoted}, new_loaded_paths} = do_read_quoted!(f, loaded_paths)
          {quoted, new_loaded_paths}
        f, {quoted, loaded_paths} ->
          if f in loaded_paths do
            raise ArgumentError, message: "recursive load of #{f} detected"
          end
          # Again, extract the quoted body, strip the `use`, and concat to the
          # head of the merged quoted body
          {{:__block__, _, f_quoted}, new_loaded_paths} = do_read_quoted!(f, loaded_paths)
          f_quoted =
            f_quoted
            |> Enum.reject(fn
              {:use, _, [{:__aliases__, _, [:Mix, :Config]}]} -> true
              _ -> false
            end)
          {Enum.concat(quoted, f_quoted), new_loaded_paths}
      end)
    # In the final step, reverse the quoted body so that they are in the file
    # in the order they were traversed, and wrap them all in a block
    {{:__block__, [], final_quoted}, new_loaded_paths}
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
      e in [Mix.Config.LoadError] -> reraise(e, System.stacktrace())
      e -> reraise(Mix.Config.LoadError, [file: file, error: e], System.stacktrace())
    end
  end

  defp merge_imports({:__block__, _, block}, acc, file, loaded_paths) do
    merge_imports(block, acc, file, loaded_paths)
  end

  defp merge_imports(item, acc, file, loaded_paths) when is_tuple(item) do
    merge_imports([item], acc, file, loaded_paths)
  end

  defp merge_imports([], acc, _file, _loaded_paths) do
    {:__block__, [], Enum.reverse(acc)}
  end

  defp merge_imports([{:import_config, _, [path]} | block], acc, file, loaded_paths)
       when is_binary(path) do
    path = Path.join(Path.dirname(file), Path.relative_to(path, file))

    {quoted, new_loaded_paths} = 
      if String.contains?(path, "*") do
        {{:__block__, _, quoted}, new_loaded_paths} = do_read_quoted_wildcard!(path, loaded_paths)
        {quoted, new_loaded_paths}
      else
        {{:__block__, _, quoted}, new_loaded_paths} = do_read_quoted!(path, loaded_paths)
        {quoted, new_loaded_paths}
      end

    new_acc =
      quoted
      |> Enum.reject(fn
        {:use, _, [{:__aliases__, _, [:Mix, :Config]}]} -> true
        _ -> false
      end)
      |> Enum.reverse()
      |> Enum.concat(acc)

    merge_imports(block, new_acc, file, new_loaded_paths)
  end

  defp merge_imports([{:import_config, _, [path_expr]} | block], acc, file, loaded_paths) do
    case eval_path(acc, path_expr) do
      {:error, err} ->
        raise Mix.Config.LoadError, file: file, error: err

      path ->
        path = Path.join(Path.dirname(file), Path.relative_to(path, file))
        {quoted, new_loaded_paths} =
          if String.contains?(path, "*") do
            {{:__block__, _, quoted}, new_loaded_paths} = do_read_quoted_wildcard!(path, loaded_paths)
            {quoted, new_loaded_paths}
          else
            {{:__block__, _, quoted}, new_loaded_paths} = do_read_quoted!(path, loaded_paths)
            {quoted, new_loaded_paths}
          end

        new_acc =
          quoted
          |> Enum.reject(fn
            {:use, _, [{:__aliases__, _, [:Mix, :Config]}]} -> true
            _ -> false
          end)
          |> Enum.reverse()
          |> Enum.concat(acc)

        merge_imports(block, new_acc, file, new_loaded_paths)
    end
  end

  defp merge_imports([{:config, env, [:kernel | _]} = other | rest], acc, file, loaded_paths) do
    line = Keyword.get(env, :line, "N/A")
    file_path = Path.relative_to_cwd(file)

    Logger.warn(
      "Found config setting for :kernel application in Mix config!\n" <>
        "    File: #{file_path}\n" <>
        "    Line: #{line}\n" <>
        "    Any :kernel config settings need to be placed in vm.args, or they will not take effect!"
    )

    merge_imports(rest, [other | acc], file, loaded_paths)
  end

  defp merge_imports([other | rest], acc, file, loaded_paths) do
    merge_imports(rest, [other | acc], file, loaded_paths)
  end

  defp eval_path(_acc, path) when is_binary(path) do
    path
  end

  defp eval_path(acc, expr) do
    # Rebuild script context without Mix.Config macros
    stripped = strip_config_macros(acc, [expr])
    quoted = {:__block__, [], stripped}

    try do
      {path, _bindings} = Code.eval_quoted(quoted)
      path
    rescue
      e ->
        {:error, e}
    end
  end

  defp strip_config_macros([], acc), do: acc

  defp strip_config_macros([{:use, _, [{:__aliases__, _, [:Mix, :Config]}]} | rest], acc) do
    strip_config_macros(rest, acc)
  end

  defp strip_config_macros([{type, _, _} | rest], acc) when type in [:import_config, :config] do
    strip_config_macros(rest, acc)
  end

  defp strip_config_macros([expr | rest], acc) do
    strip_config_macros(rest, [expr | acc])
  end
end
