defmodule Mix.Releases.Stripper do
  @moduledoc """
  Safely strip debug information from a release
  """

   #
  # These are copied directly from beam_lib.erl
  #
  def strip_release(path) do
    path
    |> to_charlist()
    |> :filename.join('lib/*/ebin/*.beam')
    |> :filelib.wildcard()
    |> strip_files()
  end

  def strip_files(files) do
    result = for f <- files, do: strip_file(f)
    {:ok, result}
  end

  def strip_file(file) do
    {:ok, {mod, chunks}} = read_significant_chunks(file, significant_chunks())
    {:ok, stripped0} = :beam_lib.build_module(chunks)
    stripped = compress(stripped0)

    case file do
      _ when is_binary(file) ->
        {:ok, {mod, stripped}}

      _ ->
        file_name = beam_filename(file)

        case :file.open(file_name, [:raw, :binary, :write]) do
          {:ok, fd} ->
            case :file.write(fd, stripped) do
              :ok ->
                :ok = :file.close(fd)
                {:ok, {mod, file_name}}

              error ->
                :ok = :file.close(fd)
                file_error(file_name, error)
            end

          error ->
            file_error(file_name, error)
        end
    end
  end

  def compress(binary0) do
    {:ok, fd} = :ram_file.open(binary0, [:write, :binary])
    {:ok, _} = :ram_file.compress(fd)
    {:ok, binary} = :ram_file.get_file(fd)
    :ok = :ram_file.close(fd)
    binary
  end

  def beam_filename(bin) when is_binary(bin) do
    bin
  end

  def beam_filename(file) do
    :filename.rootname(file, '.beam') ++ '.beam'
  end

  def read_significant_chunks(file, chunk_list) do
    case :beam_lib.chunks(file, chunk_list, [:allow_missing_chunks]) do
      {:ok, {module, chunks0}} ->
        mandatory = mandatory_chunks()
        chunks = filter_significant_chunks(chunks0, mandatory, file, module)
        {:ok, {module, chunks}}
    end
  end

  # The following chunks must be kept when stripping a BEAM file.
  def significant_chunks(), do: ['Line' | md5_chunks()]

  # The following chunks are significant when calculating the MD5
  # for a module. They are listed in the order that they should be MD5:ed.
  def md5_chunks(), do: ['Atom', 'AtU8', 'Attr', 'Code', 'StrT', 'ImpT', 'ExpT', 'FunT', 'LitT']

  # The following chunks are mandatory in every Beam file.
  def mandatory_chunks(), do: ['Code', 'ExpT', 'ImpT', 'StrT']

  def filter_significant_chunks([{_, data} = pair | cs], mandatory, file, mod)
      when is_binary(data),
      do: [pair | filter_significant_chunks(cs, mandatory, file, mod)]

  def filter_significant_chunks([{id, :missing_chunk} | cs], mandatory, file, mod) do
    case :lists.member(id, mandatory) do
      false ->
        filter_significant_chunks(cs, mandatory, file, mod)

      true ->
        error({:missing_chunk, file, id})
    end
  end

  def filter_significant_chunks([], _, _, _), do: []

  def error(reason), do: throw({:error, __MODULE__, reason})

  def error(fmt, args) do
    :error_logger.error_msg(fmt, args)
    :error
  end

  def file_error(file_name, {:error, reason}), do: error({:file_error, file_name, reason})
end
