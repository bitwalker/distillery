defmodule Distillery.Test.SoftPurgeTransform do
  use Distillery.Releases.Appup.Transform

  def up(app, _v1, _v2, instructions, opts) do
    apply_transform(instructions, app, opts)
  end

  def down(app, _v1, _v2, instructions, opts) do
    apply_transform(instructions, app, opts)
  end

  defp apply_transform(instructions, app, opts) do
    default = Keyword.get(opts, :default, :soft_purge)
    exclusions = Keyword.get(opts, :overrides, [])
    apply_transform(instructions, [], app, default, exclusions)
  end

  defp apply_transform([], acc, _app, _default, _exclusions), do: Enum.reverse(acc)

  defp apply_transform([i | ixs], acc, app, default, exclusions) do
    purge_mode = Keyword.get(exclusions, app, default)

    cond do
      elem(i, 0) == :update ->
        new_i = handle_update(i, purge_mode)
        apply_transform(ixs, [new_i | acc], app, default, exclusions)

      elem(i, 0) in [:load_module, :load] ->
        new_i = handle_load(i, purge_mode)
        apply_transform(ixs, [new_i | acc], app, default, exclusions)

      :else ->
        apply_transform(ixs, [i | acc], app, default, exclusions)
    end
  end

  defp handle_update({:update, m}, purge), do: {:update, m, :soft, purge, purge, []}
  defp handle_update({:update, _, :supervisor} = i, _purge), do: i

  defp handle_update({:update, m, dep_mods}, purge) when is_list(dep_mods),
    do: {:update, m, :soft, purge, purge, dep_mods}

  defp handle_update({:update, m, c}, purge), do: {:update, m, c, purge, purge, []}

  defp handle_update({:update, m, c, dep_mods}, purge),
    do: {:update, m, c, purge, purge, dep_mods}

  defp handle_update({:update, m, c, _, _, dep_mods}, purge),
    do: {:update, m, c, purge, purge, dep_mods}

  defp handle_update({:update, m, to, c, _, _, dep_mods}, purge),
    do: {:update, m, to, c, purge, purge, dep_mods}

  defp handle_update({:update, m, mt, to, c, _, _, dep_mods}, purge),
    do: {:update, m, mt, to, c, purge, purge, dep_mods}

  defp handle_load({:load_module, m}, purge), do: {:load_module, m, purge, purge, []}

  defp handle_load({:load_module, m, dep_mods}, purge),
    do: {:load_module, m, purge, purge, dep_mods}

  defp handle_load({:load_module, m, _, _, dep_mods}, purge),
    do: {:load_module, m, purge, purge, dep_mods}

  defp handle_load({:load, {m, _, _}}, purge), do: {:load, {m, purge, purge}}
end
