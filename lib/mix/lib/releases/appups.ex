defmodule Mix.Releases.Appup do
  @moduledoc """
  This module is responsible for generating appups between two releases.
  """

  @type app :: atom
  @type version_str :: String.t
  @type path_str :: String.t
  @type change :: {:advanced, [term]}
  @type dep_mods :: [module]

  @type appup_ver :: char_list
  @type instruction :: {:add_module, module} |
                        {:delete_module, module} |
                        {:update, module, :supervisor | change} |
                        {:update, module, change, dep_mods} |
                        {:load_module, module}
  @type upgrade_instructions :: [{appup_ver, instruction}]
  @type downgrade_instructions :: [{appup_ver, instruction}]
  @type appup :: {appup_ver, upgrade_instructions, downgrade_instructions}

  @doc """
  Generate a .appup for the given application, start version, and upgrade version.

  ## Parameters

      - application: the application name as an atom
      - v1: the previous version, such as "0.0.1"
      - v2: the new version, such as "0.0.2"
      - v1_path: the path to the v1 artifacts (rel/<app>/lib/<app>-0.0.1)
      - v2_path: the path to the v2 artifacts (_build/prod/lib/<app>)

  """
  @spec make(app, version_str, version_str, path_str, path_str) :: {:ok, appup} | {:error, term}
  def make(application, v1, v2, v1_path, v2_path) do
    v1_dotapp =
      v1_path
      |> Path.join("/ebin/")
      |> Path.join(Atom.to_string(application) <> ".app")
      |> String.to_charlist
    v2_dotapp =
      v2_path
      |> Path.join("/ebin/")
      |> Path.join(Atom.to_string(application) <> ".app")
      |> String.to_charlist

    case :file.consult(v1_dotapp) do
      {:ok, [{:application, ^application, v1_props}]} ->
        consulted_v1_vsn = vsn(v1_props)
        case consulted_v1_vsn === v1 do
          true ->
            case :file.consult(v2_dotapp) do
              {:ok, [{:application, ^application, v2_props}]} ->
                consulted_v2_vsn = vsn(v2_props)
                case consulted_v2_vsn === v2 do
                  true ->
                    appup = make_appup(v1, v1_path, v1_props, v2, v2_path, v2_props)
                    {:ok, appup}
                  false ->
                    {:error, {:appups, {:mismatched_versions, [version: :next, expected: v2, got: consulted_v2_vsn]}}}
                end
              {:error, reason} ->
                {:error, {:appups, :file, {:invalid_dotapp, reason}}}
            end
          false ->
            {:error, {:appups, {:mismatched_versions, [version: :previous, expected: v1, got: consulted_v1_vsn]}}}
        end
      {:error, reason} ->
        {:error, {:appups, :file, {:invalid_dotapp, reason}}}
    end
  end

  defp make_appup(v1, v1_path, _v1_props, v2, v2_path, _v2_props) do
    v1 = String.to_charlist(v1)
    v2 = String.to_charlist(v2)
    v1_path = String.to_charlist(Path.join(v1_path, "ebin"))
    v2_path = String.to_charlist(Path.join(v2_path, "ebin"))

    {deleted, added, changed} = :beam_lib.cmp_dirs(v1_path, v2_path)

    {v2, # New version
      [{v1, # Upgrade instructions from version v1
        generate_instructions(:added, added) ++
        generate_instructions(:changed, changed) ++
        generate_instructions(:deleted, deleted)}],
      [{v1, # Downgrade instructions to version v1
        generate_instructions(:deleted, added) ++
        generate_instructions(:changed, changed) ++
        generate_instructions(:added, deleted)}]}
  end

  # For modules which have changed, we must make sure
  # that they are loaded/updated in such an order that
  # modules they depend upon are loaded/updated first,
  # where possible (due to cyclic dependencies, this is
  # not always feasible). After generating the instructions,
  # we perform a best-effort topological sort of the modules
  # involved, such that an optimal ordering of the instructions
  # is generated
  defp generate_instructions(:changed, files) do
    files
    |> Enum.map(&generate_instruction(:changed, &1))
    |> topological_sort
  end
  defp generate_instructions(type, files) do
    Enum.map(files, &generate_instruction(type, &1))
  end

  defp generate_instruction(:added, file),   do: {:add_module, module_name(file)}
  defp generate_instruction(:deleted, file), do: {:delete_module, module_name(file)}
  defp generate_instruction(:changed, {v1_file, v2_file}) do
    module_name     = module_name(v1_file)
    attributes      = beam_attributes(v1_file)
    exports         = beam_exports(v1_file)
    imports         = beam_imports(v2_file)
    is_supervisor   = is_supervisor?(attributes)
    is_special_proc = is_special_process?(exports)
    depends_on = imports
      |> Enum.map(fn {m,_f,_a} -> m end)
      |> Enum.uniq
    generate_instruction_advanced(module_name, is_supervisor, is_special_proc, depends_on)
  end

  defp beam_attributes(file) do
    {:ok, {_, [attributes: attributes]}} = :beam_lib.chunks(file, [:attributes])
    attributes
  end

  defp beam_imports(file) do
    {:ok, {_, [imports: imports]}} = :beam_lib.chunks(file, [:imports])
    imports
  end

  defp beam_exports(file) do
    {:ok, {_, [exports: exports]}} = :beam_lib.chunks(file, [:exports])
    exports
  end

  defp is_special_process?(exports) do
    Keyword.get(exports, :system_code_change) == 4 ||
    Keyword.get(exports, :code_change) == 3 ||
    Keyword.get(exports, :code_change) == 4
  end

  defp is_supervisor?(attributes) do
    behaviours = Keyword.get(attributes, :behavior, []) ++
                 Keyword.get(attributes, :behaviour, [])
    (:supervisor in behaviours) || (Supervisor in behaviours)
  end

  # supervisor
  defp generate_instruction_advanced(m, true, _is_special, _dep_mods), do: {:update, m, :supervisor}
  # special process (i.e. exports code_change/3 or system_code_change/4)
  defp generate_instruction_advanced(m, _is_sup, true, []),       do: {:update, m, {:advanced, []}}
  defp generate_instruction_advanced(m, _is_sup, true, dep_mods), do: {:update, m, {:advanced, []}, dep_mods}
  # non-special process (i.e. neither code_change/3 nor system_code_change/4 are exported)
  defp generate_instruction_advanced(m, _is_sup, false, []),       do: {:load_module, m}
  defp generate_instruction_advanced(m, _is_sup, false, dep_mods), do: {:load_module, m, dep_mods}

  # This "topological" sort is not truly topological, since module dependencies
  # are represented as a directed, cyclic graph, and it is not actually
  # possible to sort such a graph due to the cycles which occur. However, one
  # can "break" loops, until one reaches a point that the graph becomes acyclic,
  # and those topologically sortable. That's effectively what happens here:
  # we perform the sort, breaking loops where they exist by attempting to
  # weight each of the two dependencies based on the number of outgoing dependencies
  # they have, where the fewer number of outgoing dependencies always comes first.
  # I have experimented with various different approaches, including algorithms for
  # feedback arc sets, and none appeared to work as well as the one below. I'm definitely
  # open to better algorithms, because I don't particularly like this one.
  defp topological_sort(instructions) do
    mods = Enum.map(instructions, fn i -> elem(i, 1) end)
    instructions
    |> Enum.sort(&do_sort_instructions(mods, &1, &2))
    |> Enum.map(fn
      {:update, _, _} = i   -> i
      {:load_module, _} = i -> i
      {:update, m, type, deps} ->
        {:update, m, type, Enum.filter(deps, fn ^m -> false; d -> d in mods end)}
      {:load_module, m, deps} ->
        {:load_module, m, Enum.filter(deps, fn ^m -> false; d -> d in mods end)}
    end)
  end
  defp do_sort_instructions(_, {:update, a, _}, {:update, b, _}),        do: a > b
  defp do_sort_instructions(_, {:update, _, _}, {:update, _, _, _}),     do: true
  defp do_sort_instructions(_, {:update, _, _}, {:load_module, _, _}),   do: false
  defp do_sort_instructions(_, {:load_module, a}, {:load_module, b}),    do: a > b
  defp do_sort_instructions(_, {:load_module, _}, {:update, _, _, _}),   do: true
  defp do_sort_instructions(_, {:load_module, _}, {:load_module, _, _}), do: true
  defp do_sort_instructions(mods, a, b) do
    am = elem(a, 1)
    bm = elem(b, 1)
    ad = extract_deps(a)
    bd = extract_deps(b)
    do_sort_instructions(mods, am, bm, ad, bd)
  end
  defp do_sort_instructions(mods, am, bm, ad, bd) do
    ad = Enum.filter(ad, fn ^am -> false; d -> d in mods end)
    bd = Enum.filter(bd, fn ^bm -> false; d -> d in mods end)
    lad = length(ad)
    lbd = length(bd)
    cond do
      lad == 0 and lbd != 0 -> true
      lad != 0 and lbd == 0 -> false
      # If a depends on b and b doesn't depend on a
      # Then b comes first, and vice versa
      am in bd and not bm in ad -> true
      not am in bd and bm in ad -> false
      # If either they don't depend on each other,
      # or they both depend on each other, then the
      # module with the least outgoing dependencies
      # comes first. Otherwise we treat them as equal
      lad > lbd -> false
      lbd > lad -> true
      :else -> true
    end
  end

  defp extract_deps({:update, _, deps}) when is_list(deps), do: deps
  defp extract_deps({:update, _, _}),                       do: []
  defp extract_deps({:update, _, _, deps}),                 do: deps
  defp extract_deps({:load_module, _, deps}),               do: deps

  defp module_name(file) do
    Keyword.fetch!(:beam_lib.info(file), :module)
  end

  defp vsn(props) do
    {:value, {:vsn, vsn}} = :lists.keysearch(:vsn, 1, props)
    List.to_string(vsn)
  end
end
