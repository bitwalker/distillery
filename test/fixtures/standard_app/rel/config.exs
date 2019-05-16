~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Distillery.Releases.Config,
    # This sets the default release built by `mix distillery.release`
    default_release: :default,
    # This sets the default environment used by `mix distillery.release`
    default_environment: :dev

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html


# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :"&tNN%@WG3w]R7Ta).Ynkyamh^l0>sG1@1LFd!).=p:39^;T,eg[Ic]*:BDtF,eiT"
end

environment :prod do
  set dev_mode: false
  set strip_debug_info: false
  set include_erts: true
  set include_src: false
  set included_configs: ["extra.config"]
  set cookie: :"*GU1?EY8/~,K!9*Ohazv{O9<Ao@)pMFFKjs/q=$HlMo~q=s!~,O8!DIs0PT(v&;="
  set run_erl_env: "RUN_ERL_LOG_MAXSIZE=100000 RUN_ERL_LOG_GENERATIONS=5"

  plugin SampleApp.EnvLoggerPlugin, name: ProdPlugin
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix distillery.release`, the first release in the file
# will be used by default

release :standard_app do
  set version: "0.0.1"
  
  set config_providers: [
    {Distillery.Releases.Config.Providers.Elixir, ["${REL_DIR}/config.exs"]}
  ]
  
  set overlays: [
    {:copy, "rel/config/config.exs", "releases/<%= release_version %>/config.exs"}
  ]

  plugin SampleApp.EnvLoggerPlugin
end

