defmodule Distillery.Test.OverlayTest do
  use ExUnit.Case
  alias Distillery.Releases.{Utils, Overlays}

  @fixtures_path Path.join([__DIR__, "..", "fixtures"])
  @output_dir Path.join([@fixtures_path, "mock_app", "_build", "test", "rel", "mock_app"])

  setup_all do
    File.mkdir_p!(@output_dir)
  end

  describe "apply" do
    test "invalid overlay produces error" do
      overlay = {:foobar, "baz"}
      assert {:error, {:invalid_overlay, ^overlay}} = Overlays.apply(@output_dir, [overlay], [])
    end

    test "invalid template string produces error" do
      str = "<%= foo() %>"
      expected = "undefined function foo/0 (there is no such import)"

      assert {:error, {:template_str, {^str, ^expected}}} =
               Overlays.apply(@output_dir, [{:mkdir, str}], [])
    end

    test "invalid template file produces error" do
      file = Path.join([@fixtures_path, "mock_app", "invalid_tmpl.eex"])
      expected = %CompileError{description: "undefined function foo/0 (there is no such import)", file: file, line: 1}

      assert {:error, {:template, ^expected}} =
               Overlays.apply(@output_dir, [{:template, file, "invalid_tmpl.txt"}], [])
    end

    test "file system errors are handled" do
      from = Path.join([@fixtures_path, "mock_app", "nodir"])
      to = "nodir"
      overlay = {:copy, from, to}

      assert {:error, {:overlay_failed, :file, {:enoent, ^from, ^overlay}}} =
               Overlays.apply(@output_dir, [overlay], [])
    end
  end

  describe "mkdir overlays" do
    test "mkdir creates directory" do
      result =
        Overlays.apply(@output_dir, [{:mkdir, "<%= release_name %>_test"}], release_name: :mkdir)

      dir_path = Path.join(@output_dir, "mkdir_test")
      created? = File.exists?(dir_path)

      if created? do
        File.rm_rf!(dir_path)
      end

      assert created?
      assert {:ok, ["mkdir_test"]} = result
    end
  end

  describe "copy overlays" do
    test "copy actually copies" do
      result =
        Overlays.apply(
          @output_dir,
          [{:copy, "priv/templates/release_rc_entry.eex", "<%= release_name %>.eex"}],
          release_name: :copy
        )

      copied_path = Path.join(@output_dir, "copy.eex")
      created? = File.exists?(copied_path)

      if created? do
        File.rm!(copied_path)
      end

      assert created?
      assert {:ok, ["copy.eex"]} = result
    end

    test "copy is recursive" do
      result =
        Overlays.apply(@output_dir, [{:copy, "priv", "<%= release_name %>"}], release_name: :copy)

      copied_path = Path.join(@output_dir, "copy")
      created? = File.exists?(copied_path)
      is_dir? = File.dir?(copied_path)
      is_recursive? = File.exists?(Path.join([copied_path, "templates", "release_rc_entry.eex"]))

      if created? do
        File.rm_rf!(copied_path)
      end

      assert created?
      assert is_dir?
      assert is_recursive?
      assert {:ok, ["copy"]} = result
    end
  end

  describe "link overlays" do
    test "link actually symlinks" do
      result =
        Overlays.apply(
          @output_dir,
          [{:link, "priv/templates/release_rc_entry.eex", "<%= release_name %>.eex"}],
          release_name: :link
        )

      symlinked_path = Path.join(@output_dir, "link.eex")

      symlinked? =
        case :file.read_link_info('#{symlinked_path}') do
          {:ok, info} -> elem(info, 2) == :symlink
          _ -> false
        end

      if symlinked? do
        File.rm!(symlinked_path)
      end

      assert symlinked?
      assert {:ok, ["link.eex"]} = result
    end
  end

  describe "template overlays" do
    test "template is generated correctly" do
      result =
        Overlays.apply(
          @output_dir,
          [{:template, "test/fixtures/mock_app/template_test.eex", "<%= release_name %>.txt"}],
          release_name: :template
        )

      templated_path = Path.join(@output_dir, "template.txt")
      created? = File.exists?(templated_path)

      contents =
        case created? do
          true ->
            txt = File.read!(templated_path)
            File.rm!(templated_path)
            txt

          false ->
            ""
        end

      assert created?
      assert "hi from release (template)!#{Utils.newline()}" == contents
      assert {:ok, ["template.txt"]} = result
    end
  end
end
