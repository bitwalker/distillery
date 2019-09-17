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
  * `rpc --file path/to/script` - takes a path to an Elixir script and executes it on
    the remote node
  * `eval EXPR` - takes a string of Elixir code, and executes it on a clean
    node, with no applications started (similar to how `command` worked)
  * `eval --file path/to/script` - takes a path to an Elixir script and executes it on
    a clean node

Additionally, you can pass `--mfa "Module.fun/arity"` to execute the given MFA using arguments
passed to the `rpc` or `eval` command (depending on which was called). The number of arguments passed
must match the arity of the function. Use `--argv` with `--mfa` to pass all arguments as a single
list of arguments, such as you'd get back from `:init.get_plain_arguments/0` or receive in a Mix task.

Here are some examples:

  * `command Elixir.MyApp.Release.Tasks migrate` becomes `eval 'MyApp.Release.Tasks.migrate()'`,
     or `eval --mfa 'MyApp.Release.Tasks.migrate/0'`
  * `rpc 'Elixir.Application' get_env myapp foo` becomes `rpc
    'Application.get_env(:myapp, :foo)'`
  * `rpcterms calendar valid_date '{2018,1,1}'` becomes `rpc ':calendar.valid_date({2017,1,1})'`

**Tip**. You can build Mix task-like custom commands using `--mfa` and `--argv`, like so:

```shell
release_ctl eval --mfa "Mix.Tasks.MyTask.run/1" --argv -- "$@"
```

The end result is that are now just two commands, `rpc` and `eval`, both of which work the exact
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
    booted. See the docs and the `Distillery.Releases.Config.Provider` moduledoc for
    more information. If you are curious about what a custom provider looks
    like, check out [this library](https://github.com/bitwalker/toml-elixir),
    which has a provider for TOML. Distillery also contains a provider for
    `Mix.Config` out of the box.
  * Appup Transforms! This is a plugin system for programmatically modifying
    appups during a release build. Use this to tweak the way appups are
    generated for your applications.
  * A new mix task! `mix distillery.gen.appup` allows you to generate appups for an
    application and place it under `rel` in a new directory which is checked by
    Distillery when building upgrade releases. This directory can be source
    controlled, and the generated files can be modified as needed. This is a
    much needed improvement for those performing hot upgrades!
  * PID file creation when `-kernel pidfile '"path"'` is given in `vm.args`, or
    `PIDFILE="path"` is exported in the system environment.

### Deprecations

Other than the deprecations already mentioned, there are the following:

  * The `--verbosity` flag no longer exists, use `--silent`, `--quiet` or `--verbose`,
    if you want to adjust the default output. Errors will always be output in all of
    those modes, but `--quiet` will also print warnings.
  * The `:executable` option has changed in `rel/config.exs`, rather than either `true` or
    `false`, it's either `[enabled: boolean, transient: boolean]` or `false`. In other words,
    `:executable` reflects the executable options, rather than on/off. As a result, the `:exec_opts`
    option is deprecated, and is merged into `:executable`'s options list. You can omit `:transient`
    from `:executable`, and it will be assumed to be false, as was the default behavior previously.

If you encounter an issue that is not covered here or in the documentation,
please open an bug on the issue tracker!
