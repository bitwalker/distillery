defmodule Mix.Releases.Errors do
  @moduledoc false

  @doc """
  Formats a list of errors into a human-friendly message.
  This expects a list of `{:error, _}` tuples, and will convert them
  to a single String at the end.
  """
  @spec format_error(list(term())) :: String.t
  def format_errors([err]), do: format_error(err)
  def format_errors(errs) when is_list(errs) do
    format_errors(errs, "Multiple errors detected:\n")
  end
  defp format_errors([], acc), do: acc
  defp format_errors([err|rest], acc) do
    format_errors(rest, acc <> "\n- " <> format_error(err))
  end

  @doc """
  Formats errors produced during a release into human-friendly messages
  This expects an `{:error, _}` tuple, and will convert it to a String
  """
  @spec format_error(term()) :: String.t
  def format_error(err)

  def format_error({:error, {:write_terms, mod, err}}) do
    "Failed to write file: #{mod.format_error(err)}"
  end
  def format_error({:error, {:read_terms, mod, err}}) do
    "Failed to parse file: #{mod.format_error(err)}"
  end
  def format_error({:error, {:template, err}}) do
    "Template failed: #{Exception.message(err)}"
  end
  def format_error({:error, {:template_str, {str, description}}}) do
    "Template failed, #{description}:\n" <>
    "  template: #{str}"
  end
  def format_error({:error, {:mkdir_temp, mod, err}}) do
    "Failed to create temp directory: #{mod.format_error(err)}"
  end
  def format_error({:error, {:apps, {:missing_required_lib, app, lib_dir}}}) do
    "You have included a version of ERTS which does not contain a required library\n" <>
      "    required: #{inspect app}\n" <>
      "    search path: #{Path.relative_to_cwd(lib_dir)}"
  end
  def format_error({:error, {:apps, {:invalid_start_type, app, start_type}}}) do
    "Invalid start type for #{app}: #{start_type}"
  end
  def format_error({:error, {:apps, err}}) do
    "Failed to get app metadata:\n" <>
    "    #{format_error(err)}"
  end
  def format_error({:error, {:appups, mod, {:invalid_dotapp, reason}}}) do
    "Invalid .app file for appup generation:\n" <>
    "    #{mod.format_error(reason)}"
  end
  def format_error({:error, {:appups, {:mismatched_versions, meta}}}) do
    "Invalid appup specification, mismatched versions found:\n" <>
     Enum.join(Enum.map(meta, fn {k,v} -> "    #{k}: #{v}" end), "\n")
  end
  def format_error({:error, {:plugin, {:plugin_failed, :bad_return_value, value}}}) do
    "Plugin failed: invalid result returned\n" <>
    "    expected: nil or Release.t\n" <>
    "    got: #{inspect value}"
  end
  def format_error({:error, {:plugin, {kind, err}}}) do
    "Plugin failed: #{Exception.format(kind, err, System.stacktrace)}"
  end
  def format_error({:error, {:plugin, e}}) when is_map(e) do
    "Plugin failed: #{Exception.message(e)}"
  end
  def format_error({:error, {:invalid_overlay, overlay}}) do
    "Invalid overlay, please check to make sure it is a valid overlay type:\n" <>
    "    overlay: #{inspect overlay}"
  end
  def format_error({:error, {:overlay_failed, mod, {reason, file, overlay}}}) do
    "Overlay failed, #{mod.format_error(reason)}:\n" <>
    "    file: #{Path.relative_to_cwd(file)}\n" <>
    "    overlay: #{inspect overlay}"
  end
  def format_error({:error, :missing_environment}) do
    "Release failed, unable to load selected environment\n" <>
    "    - Make sure `rel/config.exs` has environments configured\n" <>
    "    - Make sure at least one is set as default OR\n" <>
    "    - Pass --env=<env_name> to `mix release`"
  end
  def format_error({:error, :missing_release}) do
    "Release failed, unable to load selected release\n" <>
    "    - Make sure `rel/config.exs` has at least one release configured\n" <>
    "    - Make sure at least one is set as default OR\n" <>
    "    - Pass --name=<rel_name> to `mix release`"
  end
  def format_error({:error, {:assembler, {:missing_rel, name, version, path}}}) do
    "Release failed, missing .rel file for #{name}:#{version}:\n" <>
    "    path: #{Path.relative_to_cwd(path)}"
  end
  def format_error({:error, {:assembler, {:missing_rels, name, v1, v2, path1, path2}}}) do
    "Release failed, missing .rel files for:\n" <>
    "    #{name}:#{v1} @ #{Path.relative_to_cwd(path1)}\n" <>
    "    #{name}:#{v2} @ #{Path.relative_to_cwd(path2)}"
  end
  def format_error({:error, {:assembler, {:bad_upgrade_spec, :upfrom_is_current, current_version}}}) do
    "Upgrade failed, the current version and upfrom version are the same: #{current_version}"
  end
  def format_error({:error, {:assembler, {:bad_upgrade_spec, :doesnt_exist, version, upfrom_path}}}) do
    "Upgrade failed, version #{version} does not exist:\n" <>
    "    expected at: #{Path.relative_to_cwd(upfrom_path)}"
  end
  def format_error({:error, {:assembler, {:malformed_relfile, path, rel}}}) do
    "Malformed .rel file:\n" <>
    "    path: #{Path.relative_to_cwd(path)}\n" <>
    "    contents: #{inspect rel}"
  end
  def format_error({:error, {:assembler, {:invalid_sys_config, {{line,col}, mod, err}}}}) do
    "Could not parse sys.config starting at #{line}:#{col}:\n" <>
      "    #{mod.format_error(err)}"
  end
  def format_error({:error, {:assembler, {:invalid_sys_config, {line, mod, err}}}}) do
    "Could not parse sys.config starting at line #{line}:\n" <>
    "    #{mod.format_error(err)}"
  end
  def format_error({:error, {:assembler, {:invalid_sys_config, :invalid_terms}}}) do
    "Invalid sys.config: must be a list of {:app_name, [{:key, value}]} tuples"
  end
  def format_error({:error, {:assembler, :erts_missing_for_upgrades}}) do
    "Invalid configuration:\n" <>
    "    Hot upgrades will fail when include_erts: false is set,\n" <>
    "    you need to set include_erts to true or a path if you plan to use them!"
  end
  def format_error({:error, {:assembler, {:invalid_erts_path, path, maybe_path}}}) do
    "Invalid ERTS path, did you mean #{maybe_path} instead of #{path}?"
  end
  def format_error({:error, {:assembler, {:make_boot_script, {:unknown, file}}}}) do
    "Release failed, unable to generate boot script for an unknown reason\n" <>
    "    Please open an issue and include the contents of #{file}"
  end
  def format_error({:error, {:assembler, {:make_boot_script, reason}}}) do
    "Release failed, during .boot generation:\n" <>
    "    #{reason}"
  end
  def format_error({:error, {:assembler, mod, {:start_clean, reason}}}) do
    "Release failed during start_clean.boot generation:\n" <>
    "    #{mod.format_error(reason)}"
  end
  def format_error({:error, {:assembler, {:start_clean, :unknown}}}) do
    "Release failed, unable to generate start_clean.boot for unknown reasons\n" <>
    "    Please open an issue for this problem."
  end
  def format_error({:error, {:assembler, {:start_clean, reason}}}) do
    "Release failed, unable to generate start_clean.boot:\n" <>
      "    #{reason}"
  end
  def format_error({:error, {:assembler, mod, {:copy_app, app_dir, target_dir, reason}}}) do
    "Failed to copy application: #{mod.format_error(reason)}\n" <>
    "    app dir: #{Path.relative_to_cwd(app_dir)}\n" <>
    "    target dir: #{Path.relative_to_cwd(target_dir)}"
  end
  def format_error({:error, {:assembler, mod, {:copy_app, target_dir, reason}}}) do
    "Failed to copy application: #{mod.format_error(reason)}\n" <>
      "    target dir: #{Path.relative_to_cwd(target_dir)}"
  end
  def format_error({:error, {:assembler, mod, {:include_erts, reason, file}}}) do
    "Failed to include ERTS: #{mod.format_error(reason)}\n" <>
    "    file: #{Path.relative_to_cwd(file)}"
  end
  def format_error({:error, {:assembler, mod, {:include_erts, reason}}}) do
    "Failed to include ERTS: #{mod.format_error(reason)}"
  end
  def format_error({:error, {:assembler, mod, {reason, file}}}) do
    "Release failed, #{mod.format_error(reason)}:\n" <>
      "    file: #{Path.relative_to_cwd(file)}"
  end
  def format_error({:error, {:assembler, mod, reason}}) do
    "Release failed: #{mod.format_error(reason)}"
  end
  def format_error({:error, {:assembler, err}}) when is_binary(err) do
    "Release failed with multiple errors:\n" <> err
  end
  def format_error({:error, {:assembler, e}}) when is_map(e) do
    "Release failed during assembly:\n" <>
      "    #{Exception.message(e)}"
  end
  def format_error({:error, {:assembler, {:error, reason}}}) do
    "Release failed: #{Exception.format(:error, reason, System.stacktrace)}"
  end
  def format_error({:error, {:assembler, {area, err}}}) when is_map(err) do
    "Release failed (#{area}): #{Exception.message(err)}"
  end
  def format_error({:error, {:tar_generation_warn, mod, warnings}}) do
    "Release packaging failed due to warnings:\n" <>
    "    #{mod.format_warning(warnings)}"
  end
  def format_error({:error, {:tar_generation_error, mod, errors}}) do
    "Release packaging failed due to errors:\n" <>
    "    #{mod.format_error(errors)}"
  end
  def format_error({:error, {:tar_generation_error, reason}}) do
    "Release packaging failed unexpectedly: #{inspect reason}"
  end
  def format_error({:error, {:executable, {mod, reason}}}) do
    "Failed to generate executable: #{mod.format_error(reason)}"
  end
  def format_error({:error, {:archiver, {mod, reason}}}) do
    "Failed to archive release: #{mod.format_error(reason)}"
  end
  def format_error({:error, {:archiver, {mod, reason, file}}}) do
    "Failed to archive release: #{mod.format_error(reason)}\n" <>
    "    file: #{Path.relative_to_cwd(file)}"
  end
  def format_error({:error, {:archiver, e}}) when is_map(e) do
    "Failed to archive release: #{Exception.message(e)}"
  end
  def format_error({:error, {:invalid_erts, :missing_directory}}) do
    "Invalid ERTS: missing erts-* directory:\n" <>
    "    Please check the path you provided to the `include_erts` option."
  end
  def format_error({:error, {:invalid_erts, :too_many}}) do
    "Invalid ERTS: ambiguous path, too many erts-* directories found\n" <>
      "    Please ensure the path you provided to `include_erts` contains only a single erts-* directory."
  end
  def format_error({:error, {:invalid_erts, :missing_bin}}) do
    "Invalid ERTS: missing bin directory\n" <>
      "    The path you provided to `include_erts` does not contain\n" <>
      "    `erts-*/bin`, please confirm the path is correct."
  end
  def format_error({:error, {:invalid_erts, :missing_lib}}) do
    "Invalid ERTS: missing lib directory\n" <>
      "    The path you provided to `include_erts` does not contain\n" <>
      "    `erts-*/lib`, please confirm the path is correct."
  end
  def format_error({:error, {:invalid_erts, :cannot_determine_version}}) do
    "Invalid ERTS: unable to locate erts-* directory\n" <>
      "    The path you provided to `include_erts` does not contain\n" <>
      "    `erts-*`, please confirm the path is correct."
  end
  def format_error({:error, errors}) when is_list(errors),
    do: format_errors(errors)
  def format_error({:error, reason}) do
    e = Exception.message(Exception.normalize(:error, reason))
    "#{e}:\n#{Exception.format_stacktrace(System.stacktrace)}"
  end
end
