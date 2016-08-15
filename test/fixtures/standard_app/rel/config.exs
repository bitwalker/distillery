Code.require_file("rel/sample_app_plugin.ex")
Code.require_file("rel/release_plugin.ex")
use Mix.Releases.Config,
  default_environment: :dev

environment :dev do
  set dev_mode: true
  set include_erts: false
end

environment :prod do
  set dev_mode: false
  set strip_debug_info: false
  set include_erts: true
  plugin SampleApp.ProdPlugin
end

release :standard_app do
  set version: "0.0.1"
  plugin SampleApp.ReleasePlugin
end
