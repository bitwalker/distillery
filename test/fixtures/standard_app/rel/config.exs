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
end

release :standard_app do
  set version: "0.0.1"
end
