defmodule Distillery.Releases.Appup.Utils do
  @moduledoc false

  alias Distillery.Releases.Appup

  @purge_modes [:soft_purge, :brutal_purge]

  @doc """
  Given a list of appup instructions, this function determines if they are valid or not,
  returning `:ok` if they are valid, or `{:invalid, term}` if not, where the term in that
  tuple is the invalid instruction.
  """
  @spec validate_instructions([Appup.instruction()]) :: :ok | {:invalid, term}
  def validate_instructions(ixs) when is_list(ixs) do
    validate_instructions(ixs, 0)
  end

  defp validate_instructions([], _), do: :ok

  defp validate_instructions([:restart_new_emulator | rest], 0) do
    validate_instructions(rest, 1)
  end

  defp validate_instructions([:restart_new_emulator | _], _),
    do: {:invalid, :restart_new_emulator}

  defp validate_instructions([:restart_emulator], _), do: :ok
  defp validate_instructions([:restart_emulator | _], _), do: {:invalid, :restart_emulator}

  defp validate_instructions([i | rest], n) do
    if valid_instruction?(i) do
      validate_instructions(rest, n + 1)
    else
      {:invalid, i}
    end
  end

  @doc """
  Given an appup instruction, this function determines if it is valid or not,
  """
  @spec valid_instruction?(Appup.instruction()) :: boolean
  def valid_instruction?({:update, mod, :supervisor}) when is_atom(mod), do: true

  def valid_instruction?({:update, mod, {:advanced, args}}) when is_atom(mod) and is_list(args),
    do: true

  def valid_instruction?({:update, mod, dep_mods}) when is_atom(mod) and is_list(dep_mods) do
    Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:update, mod, {:advanced, args}, dep_mods})
      when is_atom(mod) and is_list(args) and is_list(dep_mods) do
    Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:update, mod, {:advanced, args}, pre_purge, post_purge, dep_mods})
      when is_atom(mod) and is_list(args) and is_list(dep_mods) do
    pre_purge in @purge_modes and post_purge in @purge_modes and Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:update, m, to, {:advanced, args}, pre, post, dep_mods})
      when is_atom(m) and is_list(args) and is_list(dep_mods) do
    pre in @purge_modes and post in @purge_modes and is_valid_timeout?(to) and
      Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:update, m, mt, to, {:advanced, args}, pre, post, dep_mods})
      when is_atom(m) and is_list(args) and is_list(dep_mods) do
    pre in @purge_modes and post in @purge_modes and is_valid_timeout?(to) and
      is_valid_modtype?(mt) and Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:load_module, mod}) when is_atom(mod), do: true

  def valid_instruction?({:load_module, mod, dep_mods}) when is_atom(mod) and is_list(dep_mods) do
    Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:load_module, mod, pre_purge, post_purge, dep_mods})
      when is_atom(mod) and is_list(dep_mods) do
    pre_purge in @purge_modes and post_purge in @purge_modes and Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:add_module, mod}) when is_atom(mod), do: true

  def valid_instruction?({:add_module, mod, dep_mods}) when is_atom(mod) and is_list(dep_mods) do
    Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:delete_module, mod}) when is_atom(mod), do: true

  def valid_instruction?({:delete_module, mod, dep_mods})
      when is_atom(mod) and is_list(dep_mods) do
    Enum.all?(dep_mods, &is_atom/1)
  end

  def valid_instruction?({:apply, {mod, fun, args}}) do
    is_atom(mod) and is_atom(fun) and is_list(args)
  end

  def valid_instruction?({:add_application, app}) when is_atom(app), do: true

  def valid_instruction?({:add_application, app, start_type}) when is_atom(app) do
    is_valid_start_type?(start_type)
  end

  def valid_instruction?({:remove_application, app}) when is_atom(app), do: true
  def valid_instruction?({:restart_application, app}) when is_atom(app), do: true
  def valid_instruction?(:restart_new_emulator), do: true
  def valid_instruction?(:restart_emulator), do: true

  def valid_instruction?({:load_object_code, {app, vsn, mods}}) do
    is_atom(app) and is_list(vsn) and is_list(mods) and Enum.all?(mods, &is_atom/1)
  end

  def valid_instruction?(:point_of_no_return), do: true

  def valid_instruction?({:load, {mod, pre_purge, post_purge}}) when is_atom(mod) do
    pre_purge in @purge_modes and post_purge in @purge_modes
  end

  def valid_instruction?({:remove, {mod, pre_purge, post_purge}}) when is_atom(mod) do
    pre_purge in @purge_modes and post_purge in @purge_modes
  end

  def valid_instruction?({:suspend, mods}) when is_list(mods) do
    Enum.all?(mods, fn
      m when is_atom(m) ->
        true

      {m, to} when is_atom(m) ->
        is_valid_timeout?(to)

      _ ->
        false
    end)
  end

  def valid_instruction?({i, mods})
      when i in [:start, :stop, :resume, :purge] and is_list(mods) do
    Enum.all?(mods, &is_atom/1)
  end

  def valid_instruction?({:code_change, mods}) when is_list(mods) do
    Enum.all?(mods, fn
      {mod, _extra} -> is_atom(mod)
      _ -> false
    end)
  end

  def valid_instruction?({:code_change, mode, mods})
      when is_list(mods) and mode in [:up, :down] do
    Enum.all?(mods, fn
      {mod, _extra} -> is_atom(mod)
      _ -> false
    end)
  end

  def valid_instruction?({:sync_nodes, _id, nodelist}) when is_list(nodelist) do
    Enum.all?(nodelist, &is_atom/1)
  end

  def valid_instruction?({:sync_nodes, _id, {m, f, a}}) do
    is_atom(m) and is_atom(f) and is_list(a)
  end

  # Unknown instruction, or invalid construction
  def valid_instruction?(_), do: false

  defp is_valid_modtype?(:static), do: true
  defp is_valid_modtype?(:dynamic), do: true
  defp is_valid_modtype?(_), do: false

  defp is_valid_timeout?(:default), do: true
  defp is_valid_timeout?(:infinity), do: true
  defp is_valid_timeout?(timeout) when is_integer(timeout) and timeout > 0, do: true
  defp is_valid_timeout?(_), do: false

  defp is_valid_start_type?(:permanent), do: true
  defp is_valid_start_type?(:transient), do: true
  defp is_valid_start_type?(:temporary), do: true
  defp is_valid_start_type?(:load), do: true
  defp is_valid_start_type?(:none), do: true
  defp is_valid_start_type?(_), do: false
end
