# Getting started

To use Distillery, you will first need to add it to your project dependencies, then run
`mix do deps.get, compile` to make it available as a task.

```elixir
defp deps do
  [
    {:distillery, "~> 2.0"}
  ]
end
```

## Initial configuration

Once installed, you need to run a one-time setup task which creates the configuration file Distillery
uses to define releases and environments. To do so, you just need to run the `distillery.init` task:

    $ mix distillery.init


!!! tip
    To get more details about the `distillery.init` task, or any others, use the `help` task:

        mix help distillery.init

    This will provide more information about available flags, and usage examples for the given task.

If you are adding Distillery to an umbrella project, you may want to use the `--release-per-app` flag
here, depending on whether you want a default configuration that puts all applications in the umbrella
in a single release (the default), or build a release for each application individually. You can always
modify the generated config to define releases using whatever combination of applications you like.

The output of `distillery.init` is a config file, `rel/config.exs`, which is an Elixir script much like
`config/config.exs`, and is used to define releases and environment-specific release configuration.
An example of what those look like is below:

```elixir
# Defines a release called :myapp, if applications aren't specified
# Distillery will assume that an application called :myapp exists and
# add that application and all of it's runtime dependencies to the release
# automatically.
release :myapp do
  set version: current_version(:myapp)
end

# Defines environment-specific configuration which should override what is set
# in the release definition. Distillery by default will select an environment based
# on the value of `MIX_ENV`, but that can be overridden with the `--env` or `--profile` flags.
environment :prod do
  # Will ensure that the Erlang Runtime System is included in the release
  set include_erts: true
  # Specifies a custom vm.args file for prod
  set vm_args: "rel/prod.vm.args"
end
```

There are a large number of options you can set in either the release or environment definition. You
can find out more about these in [Configuring Distillery](../config/distillery.md).

## Your first release

!!! warning
    If you are on Windows, building a release with `MIX_ENV=dev` will try to
    create symlinks, which requires administrator privileges. Elixir gotchas on
    Windows in general are described
    [here](https://github.com/elixir-lang/elixir/wiki/Windows#gotchas). There is
    also a solution for enabling normal users to create symlinks [see here for more](https://superuser.com/a/125981).

Now that you have an initial configuration generated, you are ready to start building releases!
The command used to do so is `mix distillery.release`:

```
$ mix distillery.release
==> distillery
Compiling 33 files (.ex)
Generated distillery app
==> test
Compiling 6 files (.ex)
Generated test app
==> Assembling release..
==> Building release test:0.1.0 using environment dev
==> You have set dev_mode to true, skipping archival phase
Release succesfully built!
To start the release you have built, you can use one of the following tasks:

    # start a shell, like 'iex -S mix'
    > _build/dev/rel/test/bin/test console

    # start in the foreground, like 'mix run --no-halt'
    > _build/dev/rel/test/bin/test foreground

    # start in the background, must be stopped with the 'stop' command
    > _build/dev/rel/test/bin/test start

If you started a release elsewhere, and wish to connect to it:

    # connects a local shell to the running node
    > _build/dev/rel/test/bin/test remote_console

    # connects directly to the running node's console
    > _build/dev/rel/test/bin/test attach

For a complete listing of commands and their use:

    > _build/dev/rel/test/bin/test help
```

!!! info
    The default configuration will select an environment from the configuration which matches
    the value of `MIX_ENV`, i.e. the result of `Mix.env/0`. You can use a release environment
    different from `MIX_ENV` with the `--env` flag:

        $ MIX_ENV=prod mix distillery.release --env=staging

Since we're building with `MIX_ENV=dev` (the default Mix environment), the release is built using
the default release and `:dev` environment from the config file (one of the default environments generated).
The `:dev` environment enables `:dev_mode` by default, which modifies the behavior of the release assembler
so that it is ideal for rapid iteration.

!!! warning
    Do not enable `:dev_mode` in situations other than development against the release! It is not
    intended for deployment, only local development.

Now that you have been introduced to how Distillery works, you have a few options on how to proceed:

  * Learn more about releases in [Understanding Releases](understanding_releases.md)
  * Learn more about release configuration in [Configuring Distillery](../config/distillery.md)
  * Check out a more in-depth walkthrough in [Walkthrough](walkthrough.md)
  * Check out one of our complete guides to deployment under *Configuration* in the side bar
