defmodule Mix.Releases.Utils do
  @moduledoc false
  alias Mix.Releases.{Logger, Release, App}

  @doc """
  Loads a template from :distillery's `priv/templates` directory based on the provided name.
  Any parameters provided are configured as bindings for the template

  ## Example

      iex> {:ok, contents} = #{__MODULE__}.template("vm.args", [release_name: :test])
      ...> String.contains?(contents, "-name test@127.0.0.1")
      true
  """
  @spec template(atom | String.t, Keyword.t) :: {:ok, String.t} | {:error, String.t}
  def template(name, params \\ []) do
    try do
      template_path = Path.join(["#{:code.priv_dir(:distillery)}", "templates", "#{name}.eex"])
      {:ok, EEx.eval_file(template_path, params)}
    rescue
      e ->
        {:error, e.__struct__.message(e)}
    end
  end

  @doc """
  Writes an Elixir/Erlang term to the provided path
  """
  @spec write_term(String.t, term) :: :ok | {:error, term}
  def write_term(path, term) do
    :file.write_file('#{path}', :io_lib.fwrite('~p.\n', [term]), [encoding: :utf8])
  end

  @doc """
  Writes a collection of Elixir/Erlang terms to the provided path
  """
  @spec write_terms(String.t, [term]) :: :ok | {:error, term}
  def write_terms(path, terms) when is_list(terms) do
    contents = String.duplicate("~p.\n\n", Enum.count(terms))
       |> String.to_char_list
       |> :io_lib.fwrite(Enum.reverse(terms))
    :file.write_file('#{path}', contents, [encoding: :utf8])
  end

  @doc """
  Reads a file as Erlang terms
  """
  @spec read_terms(String.t) :: {:ok, [term]} :: {:error, String.t}
  def read_terms(path) do
    case :file.consult(String.to_charlist(path)) do
      {:ok, _} = result ->
        result
      {:error, {line, type, msg}} ->
        {:error, "Parse failed - #{path}@#{line} (#{type}): #{msg}"}
      {:error, reason} ->
        {:error, "Unable to access #{path} (#{reason})"}
    end
  end

  @doc """
  Determines the current ERTS version
  """
  @spec erts_version() :: String.t
  def erts_version, do: "#{:erlang.system_info(:version)}"

  @doc """
  Detects the version of ERTS in the given directory
  """
  @spec detect_erts_version(String.t) :: {:ok, Stringt} | {:error, term}
  def detect_erts_version(path) when is_binary(path) do
    entries = Path.expand(path)
    |> Path.join("erts-*")
    |> Path.wildcard
    case entries do
      [<<"erts-", vsn::binary>>] ->
        {:ok, vsn}
      _ ->
        {:error, "invalid ERTS path, cannot determine version"}
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
      :ok -> {:ok, tmpdir_path}
      {:error, _} = err -> err
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
  @spec get_release_versions(String.t) :: list(String.t)
  def get_release_versions(output_dir) do
    releases_path = Path.join([output_dir, "releases"])
    case File.exists?(releases_path) do
      false -> []
      true  ->
        releases_path
        |> File.ls!
        |> Enum.reject(fn entry -> entry in ["RELEASES", "start_erl.data"] end)
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
        case { parse_version(v1str), parse_version(v2str) } do
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
  def get_apps(%Release{name: name, applications: apps}) do
    children = get_apps(App.new(name), [])
    apps = Enum.reduce(apps, children, fn
      _, {:error, _} = err ->
        err
      {a, start_type}, acc ->
        case Enum.any?(acc, fn %App{name: ^a} -> true; _ -> false end) do
          true  -> acc
          false -> get_apps(App.new(a, start_type), acc)
        end
      a, acc when is_atom(a) ->
        case Enum.any?(acc, fn %App{name: ^a} -> true; _ -> false end) do
          true  -> acc
          false -> get_apps(App.new(a), acc)
        end
    end)
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
              "      #{Enum.map(app.applications, &Atom.to_string/1) |> Enum.join("\n      ")}", :plain
        end
        case app.included_applications do
          [] ->
            Logger.debug "    includes: none\n", :plain
          _ ->
            Logger.debug "    includes:\n" <>
              "      #{Enum.map(app.included_applications, &Atom.to_string/1) |> Enum.join("\n     ")}", :plain
        end
      end)
    end
    apps
  end
  defp get_apps(nil, acc), do: Enum.uniq(acc)
  defp get_apps({:error, _} = err, _acc), do: err
  defp get_apps(%App{} = app, acc) do
    new_acc = app.applications
    |> Enum.concat(app.included_applications)
    |> Enum.reduce([app|acc], fn
      {:error, _} = err, _acc ->
        err
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
end
