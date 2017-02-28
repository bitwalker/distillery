defmodule Mix.Releases.Utils do
  @moduledoc false
  alias Mix.Releases.{Logger, Release, App}

  @doc """
  Loads a template from :distillery's `priv/templates` directory based on the provided name.
  Any parameters provided are configured as bindings for the template

  ## Example

      iex> {:ok, contents} = #{__MODULE__}.template("erl_script", [erts_vsn: "8.0"])
      ...> String.contains?(contents, "erts-8.0")
      true
  """
  @spec template(atom | String.t, Keyword.t) :: {:ok, String.t} | {:error, String.t}
  def template(name, params \\ []) do
    Path.join(["#{:code.priv_dir(:distillery)}", "templates", "#{name}.eex"])
    |> template_path(params)
  end

  @doc """
  Loads a template from the provided path
  Any parameters provided are configured as bindings for the template

  ## Example
      iex> path = Path.join(["#{:code.priv_dir(:distillery)}", "templates", "erl_script.eex"])
      ...> {:ok, contents} = #{__MODULE__}.template_path(path, [erts_vsn: "8.0"])
      ...> String.contains?(contents, "erts-8.0")
      true
  """
  @spec template_path(String.t, Keyword.t) :: {:ok, String.t} | {:error, String.t}
  def template_path(template_path, params \\ []) do
    {:ok, EEx.eval_file(template_path, params)}
  rescue
    e -> {:error, {:template, e}}
  end

  @doc """
  Writes an Elixir/Erlang term to the provided path
  """
  @spec write_term(String.t, term) :: :ok | {:error, term}
  def write_term(path, term) do
    path = String.to_charlist(path)
    contents = :io_lib.fwrite('~p.\n', [term])
    case :file.write_file(path, contents, [encoding: :utf8]) do
      :ok -> :ok
      {:error, reason} ->
        {:error, {:write_terms, :file, reason}}
    end
  end

  @doc """
  Writes a collection of Elixir/Erlang terms to the provided path
  """
  @spec write_terms(String.t, [term]) :: :ok | {:error, term}
  def write_terms(path, terms) when is_list(terms) do
    contents = String.duplicate("~p.\n\n", Enum.count(terms))
       |> String.to_char_list
       |> :io_lib.fwrite(Enum.reverse(terms))
    case :file.write_file('#{path}', contents, [encoding: :utf8]) do
      :ok -> :ok
      {:error, reason} ->
        {:error, {:write_terms, :file, reason}}
    end
  end

  @doc """
  Reads a file as Erlang terms
  """
  @spec read_terms(String.t) :: {:ok, [term]} :: {:error, String.t}
  def read_terms(path) do
    case :file.consult(String.to_charlist(path)) do
      {:ok, _} = result ->
        result
      {:error, reason} ->
        {:error, {:read_terms, :file, reason}}
    end
  end

  @doc """
  Determines the current ERTS version
  """
  @spec erts_version() :: String.t
  def erts_version, do: "#{:erlang.system_info(:version)}"

  @doc """
  Verified that the ERTS path provided is the right one.
  If no ERTS path is specified it's fine. Distillery will work out
  the system ERTS
  """
  @spec validate_erts(String.t | nil | boolean) :: :ok | {:error, [{:error, term}]}
  def validate_erts(path) when is_binary(path) do
    erts = case Path.join(path, "erts-*") |> Path.wildcard |> Enum.count do
      0 -> {:error, {:invalid_erts, :missing_directory}}
      1 -> :ok
      _ -> {:error, {:invalid_erts, :too_many}}
    end
    bin = case File.exists?(Path.join(path, "bin")) do
      false -> {:error, {:invalid_erts, :missing_bin}}
      true -> :ok
    end
    lib = case File.exists?(Path.join(path, "lib")) do
      false -> {:error, {:invalid_erts, :missing_lib}}
      true -> :ok
    end
    errors =
      Enum.filter_map(
        [erts, bin, lib],
        fn x -> x != :ok end,
        fn {:error, _} = err -> err end)
    case Enum.empty?(errors) do
      true -> :ok
      false ->
        {:error, errors}
    end
  end
  def validate_erts(include_erts) when is_nil(include_erts) or is_boolean(include_erts),
    do: :ok

  @doc """
  Detects the version of ERTS in the given directory
  """
  @spec detect_erts_version(String.t) :: {:ok, Stringt} | {:error, term}
  def detect_erts_version(path) when is_binary(path) do
    entries = Path.expand(path)
    |> Path.join("erts-*")
    |> Path.wildcard
    |> Enum.map(&Path.basename/1)
    case entries do
      [<<"erts-", vsn::binary>>] ->
        {:ok, vsn}
      _ ->
        {:error, {:invalid_erts, :cannot_determine_version}}
    end
  end

  @doc """
  Creates a temporary directory with a random name in a canonical
  temporary files directory of the current system
  (i.e. `/tmp` on *NIX or `./tmp` on Windows)

  Returns an ok tuple with the path of the temp directory, or an error
  tuple with the reason it failed.
  """
  @spec insecure_mkdir_temp() :: {:ok, String.t} | {:error, term}
  def insecure_mkdir_temp() do
    :rand.seed(:exs64)
    unique_num = :rand.uniform(1_000_000_000)
    tmpdir_path = case :erlang.system_info(:system_architecture) do
                    'win32' ->
                      Path.join(["./tmp", ".tmp_dir#{unique_num}"])
                    _ ->
                      Path.join(["/tmp", ".tmp_dir#{unique_num}"])
                  end
    case File.mkdir_p(tmpdir_path) do
      :ok ->
        {:ok, tmpdir_path}
      {:error, reason} ->
        {:error, {:mkdir_temp, :file, reason}}
    end
  end

  @doc """
  Given a path to a release output directory, return a list
  of release versions that are present.

  ## Example

      iex> app_dir = Path.join([File.cwd!, "test", "fixtures", "mock_app"])
      ...> output_dir = Path.join([app_dir, "rel", "mock_app"])
      ...> #{__MODULE__}.get_release_versions(output_dir)
      ["0.2.2", "0.2.1-1-d3adb3f", "0.2.1", "0.2.0", "0.1.0"]
  """
  @valid_version_pattern ~r/^\d+.*$/
  @spec get_release_versions(String.t) :: list(String.t)
  def get_release_versions(output_dir) do
    releases_path = Path.join([output_dir, "releases"])
    case File.exists?(releases_path) do
      false -> []
      true  ->
        releases_path
        |> File.ls!
        |> Enum.filter(&Regex.match?(@valid_version_pattern, &1))
        |> sort_versions
    end
  end

  @git_describe_pattern ~r/(?<ver>\d+\.\d+\.\d+)-(?<commits>\d+)-(?<sha>[A-Ga-g0-9]+)/
  @doc """
  Sort a list of version strings, in reverse order (i.e. latest version comes first)
  Tries to use semver version compare, but can fall back to regular string compare.
  It also parses git-describe generated version strings and handles ordering them
  correctly.

  ## Example

      iex> #{__MODULE__}.sort_versions(["1.0.2", "1.0.1", "1.0.9", "1.0.10"])
      ["1.0.10", "1.0.9", "1.0.2", "1.0.1"]

      iex> #{__MODULE__}.sort_versions(["0.0.1", "0.0.2", "0.0.1-2-a1d2g3f", "0.0.1-1-deadbeef"])
      ["0.0.2", "0.0.1-2-a1d2g3f", "0.0.1-1-deadbeef", "0.0.1"]
  """
  @spec sort_versions(list(String.t)) :: list(String.t)
  def sort_versions(versions) do
    versions
    |> Enum.map(fn ver ->
        # Special handling for git-describe versions
        compared = case Regex.named_captures(@git_describe_pattern, ver) do
          nil ->
            {:standard, ver, nil}
          %{"ver" => version, "commits" => n, "sha" => sha} ->
            {:describe, <<version::binary, ?+, n::binary, ?-, sha::binary>>, String.to_integer(n)}
        end
        {ver, compared}
      end)
    |> Enum.sort(
      fn {_, {v1type, v1str, v1_commits_since}}, {_, {v2type, v2str, v2_commits_since}} ->
        case {parse_version(v1str), parse_version(v2str)} do
          {{:semantic, v1}, {:semantic, v2}} ->
            case Version.compare(v1, v2) do
              :gt -> true
              :eq ->
                case {v1type, v2type} do
                  {:standard, :standard} -> v1 > v2 # probably always false
                  {:standard, :describe} -> false   # v2 is an incremental version over v1
                  {:describe, :standard} -> true    # v1 is an incremental version over v2
                  {:describe, :describe} ->         # need to parse out the bits
                    v1_commits_since > v2_commits_since
                end
              :lt -> false
            end;
          {{_, v1}, {_, v2}} ->
            v1 >  v2
        end
      end)
    |> Enum.map(fn {v, _} -> v end)
  end

  defp parse_version(ver) do
    case Version.parse(ver) do
      {:ok, semver} -> {:semantic, semver}
      :error        -> {:unsemantic, ver}
    end
  end

  @doc """
  Gets a list of {app, vsn} tuples for the current release.

  An optional second parameter enables/disables debug logging of discovered apps.
  """
  @spec get_apps(Mix.Releases.Release.t) :: [{atom, String.t}] | {:error, String.t}
  # Gets all applications which are part of the release application tree
  def get_apps(%Release{name: name, applications: apps} = release) do
    children = get_apps(App.new(name), [])
    base_apps = Enum.reduce(apps, children, fn
      _, {:error, reason} ->
        {:error, {:apps, reason}}
      {a, start_type}, acc ->
        cond do
          App.valid_start_type?(start_type) ->
            case Enum.any?(acc, fn %App{name: ^a} -> true; _ -> false end) do
              true  ->
                # Override start type
                Enum.map(acc, fn %App{name: ^a} = app -> %{app | start_type: start_type}; app -> app end)
              false ->
                get_apps(App.new(a, start_type), acc)
            end
          :else ->
            {:error, {:apps, {:invalid_start_type, a, start_type}}}
        end
      a, acc when is_atom(a) ->
        case Enum.any?(acc, fn %App{name: ^a} -> true; _ -> false end) do
          true  -> acc
          false -> get_apps(App.new(a), acc)
        end
    end)
    # Correct any ERTS libs which should be pulled from the correct
    # ERTS directory, not from the current environment.
    apps = case release.profile.include_erts do
             true  -> base_apps
             false -> base_apps
             p when is_binary(p) ->
               lib_dir = Path.expand(Path.join(p, "lib"))
               Enum.reduce(base_apps, [], fn
                 _, {:error, {:apps, _}} = err ->
                   err
                 _, {:error, reason} ->
                   {:error, {:apps, reason}}
                 %App{name: a} = app, acc ->
                    case is_erts_lib?(app.path) do
                      false ->
                        [app|acc]
                      true ->
                        case Path.wildcard(Path.join(lib_dir, "#{a}-*")) do
                          [corrected_app_path|_] ->
                            [_, corrected_app_vsn] = String.split(Path.basename(corrected_app_path), "-", trim: true)
                            [%{app | :vsn => corrected_app_vsn,
                                     :path => corrected_app_path} | acc]
                          _ ->
                            {:error, {:apps, {:missing_required_lib, a, lib_dir}}}
                        end
                    end
               end)
           end
    case apps do
      {:error, _} = err ->
        err
      ^apps when is_list(apps) ->
        apps = Enum.reverse(apps)
        # Accumulate all unhandled deps, and see if they are present in the list
        # of applications, if so they can be ignored, if not, warn about them
        unhandled = Enum.flat_map(apps, fn %App{unhandled_deps: unhandled} ->
          unhandled
        end) |> MapSet.new
        handled = Enum.flat_map(apps, fn %App{name: a} = app ->
          Enum.concat([a | app.applications], app.included_applications)
        end) |> Enum.uniq |> MapSet.new
        ignore_missing = Application.get_env(:distillery, :no_warn_missing, [])
        missing = MapSet.to_list(MapSet.difference(unhandled, handled))
        missing = case ignore_missing do
                    false  -> missing
                    true   -> []
                    ignore ->
                      Enum.filter(missing, fn
                        a -> not Enum.member?(ignore, a)
                      end)
                  end
        case missing do
          [] -> :ok
          _ ->
            Logger.warn "One or more direct or transitive dependencies are missing from\n" <>
              "    :applications or :included_applications, they will not be included\n" <>
              "    in the release:\n\n" <>
            Enum.join(Enum.map(missing, fn a -> "    #{inspect a}" end), "\n") <>
            "\n\n    This can cause your application to fail at runtime. If you are sure\n" <>
            "    that this is not an issue, you may ignore this warning.\n"
        end
        # Print apps
        if is_list(apps) do
          Logger.debug "Discovered applications:"
          Enum.each(apps, fn %App{} = app ->
            where = Path.relative_to_cwd(app.path)
            Logger.debug "  #{IO.ANSI.reset}#{app.name}-#{app.vsn}#{IO.ANSI.cyan}\n" <>
              "    from: #{where}", :plain
            case app.applications do
              [] ->
                Logger.debug "    applications: none", :plain
              _  ->
                Logger.debug "    applications:\n" <>
                  "      #{Enum.map(app.applications, &inspect/1) |> Enum.join("\n      ")}", :plain
            end
            case app.included_applications do
              [] ->
                Logger.debug "    includes: none\n", :plain
              _ ->
                Logger.debug "    includes:\n" <>
                  "      #{Enum.map(app.included_applications, &inspect/1) |> Enum.join("\n     ")}", :plain
            end
          end)
        end
        apps
    end
  end
  defp get_apps(nil, acc), do: Enum.uniq(acc)
  defp get_apps({:error, _} = err, _acc), do: err
  defp get_apps(%App{} = app, acc) do
    new_acc = app.applications
    |> Enum.concat(app.included_applications)
    |> Enum.reduce([app|acc], fn
      {:error, _} = err, _acc ->
        err
      {a, load_type}, acc ->
        case Enum.any?(acc, fn %App{name: ^a} -> true; _ -> false end) do
          true -> acc
          false ->
            case App.new(a, load_type) do
              nil ->
                acc
              %App{} = app ->
                case get_apps(app, acc) do
                  {:error, _} = err -> err
                  children -> Enum.concat(acc, children)
                end
              {:error, _} = err ->
                err
            end
        end
      a, acc ->
        case Enum.any?(acc, fn %App{name: ^a} -> true; _ -> false end) do
          true -> acc
          false ->
            case App.new(a) do
              nil ->
                acc
              %App{} = app ->
                case get_apps(app, acc) do
                  {:error, _} = err -> err
                  children -> Enum.concat(acc, children)
                end
              {:error, _} = err ->
                err
            end
        end
    end)
    case new_acc do
      {:error, _} = err -> err
      apps -> Enum.uniq(apps)
    end
  end

  # Determines if the given application directory is part of the Erlang installation
  @spec is_erts_lib?(String.t) :: boolean
  @spec is_erts_lib?(String.t, String.t) :: boolean
  def is_erts_lib?(app_dir), do: is_erts_lib?(app_dir, "#{:code.lib_dir()}")
  def is_erts_lib?(app_dir, lib_dir), do: String.starts_with?(app_dir, lib_dir)

  @doc false
  def newline() do
    case :os.type() do
      {:win32, _} -> "\r\n"
      {:unix, _}  -> "\n"
    end
  end

end
