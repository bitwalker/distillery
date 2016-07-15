use Mix.Releases.Config

config debug?: false,
       include_erts: true

release :standard_app, version(:standard_app)
