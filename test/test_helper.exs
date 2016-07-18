Mix.Project.in_project(:standard_app, Path.join([__DIR__, "fixtures", "standard_app"]), fn _mixfile ->
  Mix.Task.run("clean", [])
  Mix.Task.run("compile", [])
end)
ExUnit.start()
