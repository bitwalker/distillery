defmodule Distillery.Releases.Archiver.Archive do
  @moduledoc false

  defstruct [:name, :working_dir, :manifest]

  @type path :: String.t()

  @type t :: %__MODULE__{
          name: String.t(),
          working_dir: path,
          manifest: %{path => path}
        }

  @doc """
  Creates a new Archive with the given name and working directory.

  The working directory is the location where added files will be considered
  to be relative to. When adding entries to the archive, we strip the working directory
  from the source path via `Path.relative_to/2` to form the path in the resulting tarball.
  """
  @spec new(name :: String.t(), path) :: t
  def new(name, working_dir) when is_binary(name) when is_binary(working_dir) do
    %__MODULE__{name: name, working_dir: working_dir, manifest: %{}}
  end

  @doc """
  Adds a new entry to the archive
  """
  @spec add(t, path) :: t
  def add(%__MODULE__{working_dir: work_dir, manifest: manifest} = archive, source_path) do
    entry_path = Path.relative_to(source_path, work_dir)
    manifest = Map.put(manifest, entry_path, source_path)
    %{archive | :manifest => manifest}
  end

  @doc """
  Adds a new entry to the archive with the given entry path
  """
  @spec add(t, path, path) :: t
  def add(%__MODULE__{manifest: manifest} = archive, source_path, entry_path) do
    %{archive | :manifest => Map.put(manifest, entry_path, source_path)}
  end

  @doc """
  Extracts the archive at the given path, into the provided target directory,
  and returns an Archive struct populated with the manifest of the extracted tarball
  """
  @spec extract(path, path) :: {:ok, t} | {:error, {:archiver, {:erl_tar, term}}}
  def extract(archive_path, output_dir) do
    with archive_path_cl = String.to_charlist(archive_path),
         output_dir_cl = String.to_charlist(output_dir),
         {:ok, manifest} <- :erl_tar.table(archive_path_cl, [:compressed]),
         manifest = Enum.map(manifest, &List.to_string/1),
         :ok <- :erl_tar.extract(archive_path_cl, [{:cwd, output_dir_cl}, :compressed]) do
      name =
        archive_path
        |> Path.basename(".tar.gz")

      archive = new(name, output_dir)

      archive =
        manifest
        |> Enum.reduce(archive, fn entry, acc ->
          add(acc, Path.join(output_dir, entry), entry)
        end)

      {:ok, archive}
    else
      {:error, err} ->
        {:error, {:archiver, {:erl_tar, err}}}
    end
  end

  @doc """
  Writes a compressed tar to the given output directory, using the archive name as the filename.

  Returns the path of the written tarball wrapped in an ok tuple if successful
  """
  @spec save(t, path) :: {:ok, path} | {:error, {:file.filename(), reason :: term}}
  def save(%__MODULE__{name: name} = archive, output_dir) when is_binary(output_dir) do
    do_save(archive, Path.join([output_dir, name <> ".tar.gz"]))
  end

  defp do_save(%__MODULE__{manifest: manifest}, out_path) do
    out_path_cl = String.to_charlist(out_path)

    case :erl_tar.create(out_path_cl, to_erl_tar_manifest(manifest), [:dereference, :compressed]) do
      :ok ->
        {:ok, out_path}

      {:error, _} = err ->
        err
    end
  end

  defp to_erl_tar_manifest(manifest) when is_map(manifest) do
    to_erl_tar_manifest(Map.to_list(manifest), [])
  end

  defp to_erl_tar_manifest([], acc), do: acc

  defp to_erl_tar_manifest([{entry, source} | manifest], acc) do
    to_erl_tar_manifest(manifest, [{String.to_charlist(entry), String.to_charlist(source)} | acc])
  end
end
