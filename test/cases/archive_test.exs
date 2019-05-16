defmodule Distillery.Test.ArchiveTest do
  use ExUnit.Case

  alias Distillery.Releases.Utils
  alias Distillery.Releases.Archiver.Archive

  setup do
    context = [
      working_dir: Utils.insecure_mkdir_temp!(),
      extract_dir: Utils.insecure_mkdir_temp!()
    ]

    for {_, path} <- context, do: File.mkdir_p!(path)

    on_exit(fn ->
      for {_, path} <- context do
        _ = File.rm_rf(path)
      end
    end)

    context
  end

  test "creating an archive behaves as expected", %{
    working_dir: working_dir,
    extract_dir: extract_dir
  } do
    File.mkdir_p!(Path.join([working_dir, "foo", "bar"]))

    baz_path = Path.join([working_dir, "foo", "bar", "baz.txt"])
    File.write!(baz_path, "hello!\n")
    qux_path = Path.join([working_dir, "qux.txt"])
    File.write!(qux_path, "hello again!\n")
    test_file_path = __ENV__.file

    archive = Archive.new("archive_test", working_dir)
    assert %Archive{name: "archive_test", working_dir: ^working_dir, manifest: %{}} = archive

    archive = Archive.add(archive, baz_path)
    assert %{"foo/bar/baz.txt" => ^baz_path} = archive.manifest

    archive = Archive.add(archive, qux_path)
    assert %{"qux.txt" => ^qux_path} = archive.manifest

    archive = Archive.add(archive, test_file_path, "test.exs")
    assert %{"test.exs" => ^test_file_path} = archive.manifest

    {:ok, target_path} = Archive.save(archive, working_dir)

    assert File.exists?(target_path)

    {:ok, extracted} = Archive.extract(target_path, extract_dir)

    assert extracted.name == archive.name
    assert extracted.working_dir == extract_dir

    assert File.exists?(extracted.manifest["test.exs"])
    assert File.exists?(Path.join([extract_dir, "test.exs"]))

    assert File.exists?(extracted.manifest["qux.txt"])
    assert File.exists?(Path.join([extract_dir, "qux.txt"]))
    assert "hello again!\n" == File.read!(extracted.manifest["qux.txt"])

    assert File.exists?(Path.join([extract_dir, "foo", "bar", "baz.txt"]))
    assert File.exists?(extracted.manifest["foo/bar/baz.txt"])
    assert "hello!\n" == File.read!(extracted.manifest["foo/bar/baz.txt"])
  end
end
