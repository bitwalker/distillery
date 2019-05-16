# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Distillery.Releases.Config,
    # This sets the default release built by `mix distillery.release`
    default_release: :default,
    # This sets the default environment used by `mix distillery.release`
    default_environment: Mix.env()


environment :dev do
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.
  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.
  set dev_mode: true
  set include_erts: false
  set cookie: :"f:okQO{}o8:7Hi^&jI4ssu{71FoJ5dFE!2Bmg}~dtzxyzpY]dmDSc!epwJ`e*k_S"
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :"$^{@jVal*|$,)nJPdZNlUsMQMUEDBh7A?~U2x^>/f`J72xpa@kbm}`}QwLIHF1yR"
  set vm_args: "rel/vm.args"
end


release :umbrella do
  set version: "0.1.0"
  set applications: [
    :runtime_tools,
    web: :permanent
  ]

  set config_providers: [
    {Distillery.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/config.exs"]}
  ]
  set overlays: [
    {:copy, "rel/config/config.exs", "etc/config.exs"}
  ]
end

