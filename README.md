# Distillery

[![Master](https://travis-ci.org/bitwalker/distillery.svg?branch=master)](https://travis-ci.org/bitwalker/distillery)
[![Hex.pm Version](http://img.shields.io/hexpm/v/distillery.svg?style=flat)](https://hex.pm/packages/distillery)

Every alchemist requires good tools, and one of the greatest tools in the alchemist's disposal
is the distillery. The purpose of the distillery is to take something and break it down to its
component parts, reassembling it into something better, more powerful. That is exactly
what this project does - it takes your Mix project and produces an Erlang/OTP release, a
distilled form of your raw application's components; a single package which can be deployed anywhere,
independently of an Erlang/Elixir installation. No dependencies, no hassle.

This is a pure-Elixir, dependency-free implementation of release generation for Elixir projects.
It is currently a standalone package, but may be integrated into Mix at some point in the future.

## Installation

Distillery requires Elixir 1.6 or greater. It works with Erlang 20+.

```elixir
defp deps do
  [{:distillery, "~> 2.0"}]
end
```

Just add as a mix dependency and use `mix release`.

If you are new to releases or Distillery, please review the [documentation](https://hexdocs.pm/distillery),
it covers just about any question you may have!

## Upgrading From 1.5.x

Many things have changed since the last 1.5 release, with a number of
deprecations, improvements, and new features. The following is a guide to the
things which you will need to change coming from 1.5, whether using Distillery
directly, or writing tools which build on Distillery:

### Custom Commands

In 1.5.x, you may have used any of the following helpers in the `bin/myapp` script:

  * `command MODULE FUN`
  * `rpc MODULE FUN ARGS`
  * `rpcterms MODULE FUN TERM`
  * `eval EXPR`
  
These have seen breaking changes:

  * `command MODULE FUN` (soft deprecated) - same as old version, switch to `eval`
  * `rpcterms MODULE FUN TERM` (hard deprecated) - removed entirely from 2.x,
    use `rpc` instead
  * `rpc EXPR` - takes a string of Elixir code, and executes it on the
    remote node
  * `eval EXPR` - takes a string of Elixir code, and executes it on a clean
    node, with no applications started (similar to how `command` worked)

Here are some examples:

  * `command Elixir.MyApp.Release.Tasks migrate` becomes `eval 'MyApp.Release.Tasks.migrate()'`
  * `rpc 'Elixir.Application' get_env myapp foo` becomes `rpc
    'Application.get_env(:myapp, :foo)'`
  * `rpcterms calendar valid_date '{2018,1,1}'` becomes `rpc ':calendar.valid_date({2017,1,1})'`
  
You may also pass `--file path/to/script.exs` to either `rpc` or `eval` to
execute an Elixir script from a file.
  
There are now just two commands, `rpc` and `eval`, both of which work the exact
same way, with the only distinction being the execution environment of the
provided script or expression - local for `eval` and remote for `rpc`. With
`eval`, the execution environment has all code available, but no applications
started, so it is ideal for things like migrations.

### Hooks

If you were using `set <event>_hook: "path/to/script.sh"` where `<event>` was any
of the lifecycle events you could hook into, e.g. `pre_start`; you must now use 
`set <event>_hooks: "path/to/directory/of/hooks"`. The path given must be a
directory, and should contain all of the hooks for that event. The old options
have been removed.

### Executables

The `exec_opts` option is deprecated, and combined with the `executable` option.
You now should use `set executable: [enabled: true, transient: boolean]` to
build an executable release with the relevant options set.

### New Features

The following have been added, and you should take a look in the docs for more
information as they are big quality of life improvements!

  * Config Providers! This is a framework for format-agnostic, source-agnostic
    runtime configuration providers, which allow you to fetch configuration and
    push it into the application env before applications in the system have
    booted. See the docs and the `Mix.Releases.Config.Provider` moduledoc for
    more information. If you are curious about what a custom provider looks
    like, check out [this library](https://github.com/bitwalker/toml-elixir),
    which has a provider for TOML. Distillery also contains a provider for
    `Mix.Config` out of the box.
  * Appup Transforms! This is a plugin system for programmatically modifying
    appups during a release build. Use this to tweak the way appups are
    generated for your applications.
  * A new mix task! `mix release.gen.appup` allows you to generate appups for an
    application and place it under `rel` in a new directory which is checked by
    Distillery when building upgrade releases. This directory can be source
    controlled, and the generated files can be modified as needed. This is a
    much needed improvement for those performing hot upgrades!
  * PID file creation when `-kernel pidfile "path"` is given in `vm.args`, or
    `PIDFILE=path` is exported in the system environment.
    
If you encounter an issue that is not covered here or in the documentation,
please open an bug on the issue tracker!

## Community/Questions/etc.

If you have questions or want to discuss Distillery, releases, or other deployment
related topics, a good starting point is the Deployment section of ElixirForum, which
can be found [here](https://elixirforum.com/c/dedicated-sections/deployment).

I can often be found in IRC on freenode, in the `#elixir-lang` channel, and there is
also an [Elixir Slack channel](https://elixir-slackin.herokuapp.com) as well, though I don't frequent that myself, there are
many people who can answer questions there.

Failing that, feel free to open an issue on the tracker with questions, and I'll do my
best to get to it in a timely fashion!

## License

MIT. See the [`LICENSE.md`](https://github.com/bitwalker/distillery/blob/master/LICENSE.md) in this repository for more details.
