defmodule Distillery.Test.ReleaseTest do
  use ExUnit.Case

  import MixTestHelper

  @app_path Path.join([__DIR__, "fixtures", "ordered_app"])
  @build_path Path.join([@app_path, "_build"])
  @boot_script Path.join([
                  @build_path,
                  "prod",
                  "rel",
                  "ordered_app",
                  "releases",
                  "0.1.0",
                  "ordered_app.script"
                ])

  test "release ordered app" do
    old_dir = File.cwd!()
    File.cd!(@app_path)
    {:ok, _} = mix("deps.get")
    {:ok, _} = mix("release", ["--no-tar"])

    assert File.exists?(@boot_script)
    {:ok, [{:script, _, lines}]} = :file.consult(@boot_script)

    prios =
      Enum.filter(lines, fn
        {:apply, {:application, :start_boot, _}} -> true
        _ -> false
      end)
      |> Enum.map(fn {:apply, {:application, :start_boot, [name | _]}} -> name end)
      |> Enum.with_index()

    assert 0 == prios[:kernel]
    assert 1 == prios[:stdlib]
    assert prios[:db_connection] > prios[:connection]
    assert prios[:ordered_app] > prios[:db_connection]
    assert prios[:ordered_app] > prios[:lager]

    {:ok, _} = File.rm_rf(@build_path)
    File.cd!(old_dir)
  end
end
