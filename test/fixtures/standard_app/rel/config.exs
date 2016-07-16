use Mix.Releases.Config,
  default_release: :standard_app,
  default_environment: :dev

environment :dev do
  set dev_mode: true
  set include_erts: false
end

environment :default do
  set dev_mode: false
  set include_erts: true
end

release :standard_app do
  set version: current_version(:standard_app)
end
