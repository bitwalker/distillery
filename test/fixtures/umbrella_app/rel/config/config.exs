import Config

# Set configuration for Phoenix endpoint
config :web, WebWeb.Endpoint,
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json",
  load_from_system_env: false,
  version: Application.spec(:web, :vsn),
  http: [port: 4000],
  url: [host: "localhost", port: 4000],
  root: ".",
  secret_key_base: "u1QXlca4XEZKb1o3HL/aUlznI1qstCNAQ6yme/lFbFIs0Iqiq/annZ+Ty8JyUCDc"

