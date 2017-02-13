defmodule Mix.Releases.Overlays do
  @moduledoc """
  This module is responsible for applying overlays to a release, prior to packaging.
  Overlays are templated with EEx, with bindings set to the values configured in `overlay_vars`.

  There are some preconfigured overlay variables, namely:
    - `erts_vsn`: The version of ERTS used by this release
    - `release_name`: The name of the current release
    - `release_version`: The version of the current release

  For example, given a release named `my_release`, version `0.1.0`:

      {:mkdir, "releases/<%= release_version %>/foo"}

  The above overlay will create a directory, `rel/my_release/releases/0.1.0/foo`. Overlay input paths are
  relative to the project root, but overlay output paths are relative to the root directory for the current
  release, which is why the directory is created in `rel/my_release`, and not in the project root.
  """
  alias Mix.Releases.Logger

  @typep overlay :: {:mkdir, String.t} |
                    {:copy, String.t, String.t} |
                    {:link, String.t, String.t} |
                    {:template, String.t, String.t}

  @typep error :: {:error, {:invalid_overlay, term}} |
                  {:error, {:template_str, term()}} |
                  {:error, {:template, term()}} |
                  {:error, {:overlay_failed, module, term, overlay}}

  @doc """
  Applies a list of overlays to the current release.
  Returns `{:ok, output_paths}` or `{:error, details}`, where `details` is
  one of the following:

    - {:invalid_overlay, term} - a malformed overlay object
    - {:template_str, desc} - templating an overlay parameter failed
    - {:template_file, file, line, desc} - a template overlay failed
    - {:overlay_failed, term, overlay} - applying an overlay failed
  """
  @spec apply(String.t, list(overlay), Keyword.t) :: {:ok, [String.t]} | error
  def apply(_ouput_dir, [], _overlay_vars), do: {:ok, []}
  def apply(output_dir, overlays, overlay_vars) do
    do_apply(output_dir, overlays, overlay_vars, [])
  end

  defp do_apply(_output_dir, [], _vars, acc),
    do: {:ok, acc}
  defp do_apply(output_dir, [overlay|rest], overlay_vars, acc) when is_list(acc) do
    case do_overlay(output_dir, overlay, overlay_vars) do
      {:ok, path} ->
        do_apply(output_dir, rest, overlay_vars, [path|acc])
      {:error, {:invalid_overlay, _}} = err -> err
      {:error, {:template_str, _}} = err    -> err
      {:error, {:template, _}} = err        -> err
      {:error, reason} ->
        {:error, {:overlay_failed, :file, {reason, overlay}}}
      {:error, reason, file} ->
        {:error, {:overlay_failed, :file, {reason, file, overlay}}}
    end
  end

  @spec do_overlay(String.t, overlay, Keyword.t) :: {:ok, String.t} | {:error, term}
  defp do_overlay(output_dir, {:mkdir, path}, vars) when is_binary(path) do
    with {:ok, path} <- template_str(path, vars),
         _           <- Logger.debug("Applying #{IO.ANSI.reset}mkdir#{IO.ANSI.cyan} overlay\n" <>
                                     "    dst: #{Path.relative_to_cwd(path)}"),
         expanded    <- Path.join(output_dir, path),
         :ok         <- File.mkdir_p(expanded),
      do: {:ok, path}
  end
  defp do_overlay(output_dir, {:copy, from, to}, vars) when is_binary(from) and is_binary(to) do
    with {:ok, from} <- template_str(from, vars),
         {:ok, to}   <- template_str(to, vars),
         _           <- Logger.debug("Applying #{IO.ANSI.reset}copy#{IO.ANSI.cyan} overlay\n" <>
                                     "    src: #{Path.relative_to_cwd(from)}\n" <>
                                     "    dst: #{Path.relative_to_cwd(to)}"),
         expanded_to <- Path.join(output_dir, to),
         {:ok, _}    <- File.cp_r(from, expanded_to),
      do: {:ok, to}
  end
  defp do_overlay(output_dir, {:link, from, to}, vars) when is_binary(from) and is_binary(to) do
    with {:ok, from} <- template_str(from, vars),
         {:ok, to}   <- template_str(to, vars),
         _           <- Logger.debug("Applying #{IO.ANSI.reset}link#{IO.ANSI.cyan} overlay\n" <>
                                     "    src: #{Path.relative_to_cwd(from)}\n" <>
                                     "    dst: #{Path.relative_to_cwd(to)}"),
         expanded_to <- Path.join(output_dir, to),
         _           <- File.rm(expanded_to),
         :ok         <- File.ln_s(from, expanded_to),
      do: {:ok, to}
  end
  defp do_overlay(output_dir, {:template, tmpl_path, to}, vars) when is_binary(tmpl_path) and is_binary(to) do
    with {:ok, tmpl_path} <- template_str(tmpl_path, vars),
         {:ok, to}        <- template_str(to, vars),
         true             <- File.exists?(tmpl_path),
         {:ok, templated} <- template_file(tmpl_path, vars),
         expanded_to      <- Path.join(output_dir, to),
         _                <- Logger.debug("Applying #{IO.ANSI.reset}template#{IO.ANSI.cyan} overlay\n" <>
                                          "    src: #{Path.relative_to_cwd(tmpl_path)}\n" <>
                                          "    dst: #{to}"),
         :ok              <- File.mkdir_p(Path.dirname(expanded_to)),
         :ok              <- File.write(expanded_to, templated),
      do: {:ok, to}
  end
  defp do_overlay(_output_dir, invalid, _), do: {:error, {:invalid_overlay, invalid}}

  @spec template_str(String.t, Keyword.t) :: {:ok, String.t} | {:error, {:template_str, term}}
  def template_str(str, overlay_vars) do
    {:ok, EEx.eval_string(str, overlay_vars)}
  rescue
    err in [CompileError] ->
      {:error, {:template_str, {str, err.description}}}
  end

  @spec template_file(String.t, Keyword.t) :: {:ok, String.t} | {:error, {:template, term}}
  def template_file(path, overlay_vars) do
    {:ok, EEx.eval_file(path, overlay_vars)}
  rescue
    e ->
      {:error, {:template, e}}
  end
end
