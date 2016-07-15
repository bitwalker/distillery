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
  alias Mix.Releases.Config.ReleaseDefinition

  @typep overlay :: {:mkdir, String.t} |
                    {:copy, String.t, String.t} |
                    {:link, String.t, String.t} |
                    {:template, String.t, String.t}

  @typep error :: {:error, {:invalid_overlay, term}} |
                  {:error, {:template_str, String.t}} |
                  {:error, {:template_file, {non_neg_integer, non_neg_integer, String.t}}} |
                  {:error, {:overlay_failed, term, overlay}}

  @doc """
  Applies a list of overlays to the current release.
  Returns `{:ok, output_paths}` or `{:error, details}`, where `details` is
  one of the following:

    - {:invalid_overlay, term} - a malformed overlay object
    - {:template_str, desc} - templating an overlay parameter failed
    - {:template_file, file, line, desc} - a template overlay failed
    - {:overlay_failed, term, overlay} - applying an overlay failed
  """
  @spec apply(ReleaseDefinition.t, String.t, list(overlay), Keyword.t) :: {:ok, [String.t]} | error
  def apply(_release, _ouput_dir, [], _overlay_vars), do: {:ok, []}
  def apply(release, output_dir, overlays, overlay_vars) do
    do_apply(release, output_dir, overlays, overlay_vars, [])
  end

  defp do_apply(_release, _output_dir, _overlays, _vars, {:error, _} = err),
    do: err
  defp do_apply(_release, _output_dir, [], _vars, acc),
    do: {:ok, acc}
  defp do_apply(release, output_dir, [overlay|rest], overlay_vars, acc) when is_list(acc) do
    case do_overlay(release, output_dir, overlay, overlay_vars) do
      {:ok, path} ->
        do_apply(release, output_dir, rest, overlay_vars, [path|acc])
      {:error, {:invalid_overlay, _}} = err -> err
      {:error, {:template_str, _}} = err    -> err
      {:error, {:template_file, _}} = err   -> err
      {:error, reason} ->
        {:error, {:overlay_failed, reason, overlay}}
    end
  end

  defp do_overlay(_release, output_dir, {:mkdir, path}, vars) when is_binary(path) do
    with {:ok, path} <- template_str(path, vars),
         expanded    <- Path.join(output_dir, path),
         :ok         <- File.mkdir_p(expanded),
      do: {:ok, path}
  end
  defp do_overlay(_release, output_dir, {:copy, from, to}, vars) when is_binary(from) and is_binary(to) do
    with {:ok, from} <- template_str(from, vars),
         {:ok, to}   <- template_str(to, vars),
         expanded_to <- Path.join(output_dir, to),
         {:ok, _}    <- File.cp_r(from, expanded_to),
      do: {:ok, to}
  end
  defp do_overlay(_release, output_dir, {:link, from, to}, vars) when is_binary(from) and is_binary(to) do
    with {:ok, from} <- template_str(from, vars),
         {:ok, to}   <- template_str(to, vars),
         expanded_to <- Path.join(output_dir, to),
         :ok         <- File.ln_s(from, expanded_to),
      do: {:ok, to}
  end
  defp do_overlay(_release, output_dir, {:template, tmpl_path, to}, vars) when is_binary(tmpl_path) and is_binary(to) do
    with true             <- File.exists?(tmpl_path),
         {:ok, templated} <- template_file(tmpl_path, vars),
         expanded_to      <- Path.join(output_dir, to),
         :ok              <- File.mkdir_p(Path.dirname(expanded_to)),
         :ok              <- File.write(expanded_to, templated),
      do: {:ok, to}
  end
  defp do_overlay(_release, _output_dir, invalid, _), do: {:error, {:invalid_overlay, invalid}}

  defp template_str(str, overlay_vars) do
    try do
      {:ok, EEx.eval_string(str, overlay_vars)}
    rescue
      err in [CompileError] ->
        {:error, {:template_str, err.description}}
    end
  end

  defp template_file(path, overlay_vars) do
    try do
      {:ok, EEx.eval_file(path, overlay_vars)}
    rescue
      err in [CompileError] ->
        {:error, {:template_file, {err.file, err.line, err.description}}}
    end
  end
end
