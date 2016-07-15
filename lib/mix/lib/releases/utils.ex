defmodule Mix.Releases.Utils do
  @moduledoc false

  @doc """
  Loads a template from :bundler's `priv/templates` directory based on the provided name.
  Any parameters provided are configured as bindings for the template
  """
  @spec template(atom | String.t, Keyword.t) :: String.t
  def template(name, params \\ []) do
    template_path = Path.join(["#{:code.priv_dir(:bundler)}", "templates", "#{name}.eex"])
    EEx.eval_file(template_path, params)
  end

  @doc """
  Writes an Elixir/Erlang term to the provided path
  """
  def write_term(path, term) do
    :file.write_file('#{path}', :io_lib.fwrite('~p.\n', [term]))
  end

  @doc """
  Writes a collection of Elixir/Erlang terms to the provided path
  """
  def write_terms(path, terms) when is_list(terms) do
    contents = String.duplicate("~p.\n\n", Enum.count(terms))
       |> String.to_char_list
       |> :io_lib.fwrite(Enum.reverse(terms))
    :file.write_file('#{path}', contents, [encoding: :utf8])
  end

  @doc """
  Determines the current ERTS version
  """
  @spec erts_version() :: String.t
  def erts_version, do: "#{:erlang.system_info(:version)}"

  @doc """
  Creates a temporary directory with a random name in a canonical
  temporary files directory of the current system
  (i.e. `/tmp` on *NIX or `./tmp` on Windows)

  Returns the path of the temp directory, and raises an error
  if it is unable to create the directory.
  """
  @spec insecure_mkdtemp!() :: String.t | no_return
  def insecure_mkdtemp!() do
    unique_num = trunc(:random.uniform() * 1000000000000)
    tmpdir_path = case :erlang.system_info(:system_architecture) do
                    "win32" ->
                      Path.join(["./tmp", ".tmp_dir#{unique_num}"])
                    _ ->
                      Path.join(["/tmp", ".tmp_dir#{unique_num}"])
                  end
    File.mkdir_p!(tmpdir_path)
    tmpdir_path
  end

end
