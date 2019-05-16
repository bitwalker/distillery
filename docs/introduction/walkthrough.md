# Walkthrough

!!! tip
    Before starting, please review the [Terminology](terminology.md) page to
    get familiar with the terms used in this guide.

This is a simple guide on how to use Distillery and releases in general. We will cover the following:

  * Adding Distillery to your project
  * Initializing Distillery
  * Configuring your release
  * Building your release
  * Deploying your release
  * Building an upgrade release
  * Deploying an upgrade

Let's get started!

## Adding Distillery to your project

Just add the following to your deps list in `mix.exs`:

```elixir
defp deps do
  [{:distillery, "~> 2.0"}]
end
```

Then run `mix do deps.get, compile`, and you're ready to go!

## Initializing Distillery

To set up your project for releases, Distillery will create a `rel` directory in your
project root. All files related to releases will be in this directory.

Distillery also creates `rel/config.exs`, which is the configuration file you will use
to configure Distillery and your releases. Depending on your project type, it will create
an appropriate default release configuration, along with two environments, `:dev` and `:prod`,
with typical configuration for both. You can leave this configuration untouched,
or modify it as desired. We will look at this file and discuss its contents briefly. Check out
[Configuration](../config/distillery.md) for more information on this file
and available settings.

To initialize Distillery, just run `mix distillery.init`.

!!! note
    In this walkthrough, we're making the assumption that this is not an umbrella application,
    though there are no significant differences. See [Umbrella Projects](umbrella_projects.md)
    for more details on configuration specific to that setup.

## Configuring your release

The default configuration file will look something like the following (comments stripped):

```elixir
use Distillery.Releases.Config,
    default_release: :default,
    default_environment: Mix.env()

environment :dev do
  set dev_mode: true
  set include_erts: false
end

environment :prod do
  set include_erts: true
  set include_src: false
end

release :myapp do
  set version: current_version(:myapp)
end
```

Let's talk about what these settings do from top to bottom.

!!! tip
    See [Configuring Distillery](../config/distillery.md) if you want to explore settings not covered in this guide.

```elixir
use Distillery.Releases.Config,
    default_release: :default,
    default_environment: Mix.env()
```

This loads the configuration macros required by Distillery, and sets a few
optional global settings: `default_release` and `default_environment`. These
setting specify which release and which environment to build by default if they
are not specified as options to `mix distillery.release`.

If `default_release` is set to `:default`, then the first release definition in
the file will be used. If `default_environment` is set to `:default`, then an
"empty" environment will be used, in which case the only settings applied will
be those set within a `release` block. By default, Distillery sets
`default_environment` to be the same as the name of the current Mix environment.

```elixir
environment :dev do
  set dev_mode: true
  set include_erts: false
end
```

This creates an environment called `dev`, and configures a few settings which
are optimal for quick iteration during development. `dev_mode: true` will
symlink compiled BEAM files into the release directory, instead of copying them,
which ends up being significantly faster. `include_erts: false` tells Distillery
to not copy the Erlang Runtime System (ERTS) into the release directory, and
instead just use the system-wide ERTS.

```elixir
environment :prod do
  set include_erts: true
  set include_src: false
end
```

This creates an environment called `prod`, and configures a few settings which
are optimal for a self-contained production release package. `include_erts: true`
bundles the Erlang Runtime System so that the target system does not need
to have Erlang or Elixir installed, and `include_src: false` will ensure that
unnecessary source code files are not included in the release package, reducing
the final file size of the release.

```elixir
release :myapp do
  set version: current_version(:myapp)
end
```

This creates a new release definition, named `myapp`, and sets the only required
setting for a release definition, `version` to whatever the current version of
the `myapp` application is when `mix distillery.release` is run, by using the
`current_version/1` macro.

You must have at least one release definition in the config. You do not have to
create any environments, though the example config does so for reference.

To recap, an environment is a group of settings which override those of a
release when that environment is active, a release is the specific configuration
for a group of applications which will be packaged together. In a non-umbrella
application, it is usually the case that the release is named/versioned the same
as the application being released. In umbrella applications, this may or may not
be true, depending on whether the umbrella is released per-app or as one. When
building a release, the release configuration is overlaid with the environment
configuration, to form what is called a "profile". In simpler terms, if you have
a release named `myapp`, and an environment called `dev`, the profile would be
`myapp:dev`.

## Building your release

Now that we've configured our application we can build it! Just run `mix distillery.release`. There are a few flags
to `mix distillery.release` that you may be interested in using right now:

  * `--verbose` – log detailed information about what Distillery is doing and
  metadata it discovers. If you encounter issues, you should always turn this on
  to help troubleshoot.
  * `--name=<name>` – build the release with the given name, as defined in `rel/config.exs`
  * `--env=<env>` – build the release using the given environment, as defined in `rel/config.exs`
  * `--profile=<name:env>` – build the given release profile (release + environment)

!!! tip
    See `mix help release` for more usage information and additional flags.

When you run `mix distillery.release`, you should see something like the following:

```
==> Assembling release..
==> Building release myapp:0.1.0 using environment dev
==> You have set dev_mode to true, skipping archival phase
Release succesfully built!
To start the release you have built, you can use one of the following tasks:

    # start a shell, like 'iex -S mix'
    > _build/dev/rel/myapp/bin/myapp console

    # start in the foreground, like 'mix run --no-halt'
    > _build/dev/rel/myapp/bin/myapp foreground

    # start in the background, must be stopped with the 'stop' command
    > _build/dev/rel/myapp/bin/myapp start

If you started a release elsewhere, and wish to connect to it:

    # connects a local shell to the running node
    > _build/dev/rel/myapp/bin/myapp remote_console

    # connects directly to the running node's console
    > _build/dev/rel/myapp/bin/myapp attach

For a complete listing of commands and their use:

    > _build/dev/rel/myapp/bin/myapp help
```

At this point, you can run your release as described in the output.

## Deploying your release

!!! warning
    When running `mix distillery.release` for deployment to production, you should set `MIX_ENV=prod`,
    to avoid pulling in dev dependencies, and to make sure the compiled BEAMs are optimized.

!!! note
    If you are deploying to a different OS or architecture than the build
    machine, you should either set `include_erts: false` or `include_erts: "path/to/cross/compiled/erts"`.
    The former will require that you have Erlang installed on the target
    machine, and the latter will require that you have built/installed
    Erlang on the target platform, and copied the contents of the Erlang `lib`
    directory somewhere on your build machine, then provided the path to
    that directory to `include_erts`.

Let's assume you've built your release like so, and are ready to deploy to production:

    $ MIX_ENV=prod mix distillery.release

The artifact you will want to deploy is the release tarball, which is located at
`_build/prod/rel/<name>/releases/<version>/<name>.tar.gz`.

Deployment might look something like the following:

    $ mkdir -p /opt/app
    $ cp _build/prod/rel/myapp/releases/0.1.0/myapp.tar.gz /opt/app/
    $ pushd /opt/app
    $ tar -xzf myapp.tar.gz

At this point, the release has been deployed, and it can be run with one of the
start commands, e.g. `bin/myapp start`.

!!! warning
    If you did not include ERTS, you must ensure Erlang is installed on the
    target system, along with any optional packages containing Erlang libraries
    required by your application. This Erlang installation _must_ be the same
    version as the one you built the release with, as the standard library
    applications are versioned, and your release is built against specific versions.

The following are some alternative approaches to building releases to help make
bundling ERTS easy:

  * Build the release in a Docker container running the same OS version and CPU architecture,
    then copy the tarball out of the container for deployment to the target.
  * Install Erlang in a Docker container running the same OS version and CPU architecture,
    then copy the Erlang `lib` directory back to your build machine so that you can cross-compile your release.
  * Same as the above, but use Vagrant

!!! tip
    It is recommended that you use Docker for building your releases. It is
    simple to set up, and makes automating release builds and tracking against
    production infrastructure trivial.

The `start` command of the boot script will automatically handle running your
release as a daemon, but it is also common to use `systemd`, `upstart` or
`supervisord`, in which case you will want to use the `foreground` task instead.

Once started, you can connect a shell to the running release with `bin/<name> remote_console`

!!! info
    If you started the release with the `start` task, you can stop the release with the `stop` task.

!!! info
    If you started the release with the `foreground` task, you can stop the
    release by sending an interrupt with `CTRL+C` or `kill -s INT` to shut it down gracefully.

## Building an upgrade release

!!! note
    You do not have to use hot upgrades, you can simply do rolling restarts by running `stop`, extracting
    the new release tarball over the top of the old, and running `start` to boot the release.

So you've made some changes and bumped the version of your app, and you want to perform a hot upgrade
of the target system. This is pretty simple!

    $ MIX_ENV=prod mix distillery.release --upgrade

You will now have a new tarball in `_build/prod/rel/<name>/releases/<upgrade_version>/` which you can use for the next step.

## Deploying an upgrade

!!! warning
    This part is very straightforward with an important caveat: Once you
    have deployed an upgrade, if you make a mistake in, say version X (eg,
    version X has a bug that is detected in production), you cannot "redeploy" a
    new release with the same version number (X). If you try to do so, you will
    discover that your application instance has marked version X as
    "[old](http://erlang.org/doc/man/release_handler.html)" and will refuse to
    upgrade to that version number. If you find a mistake in your application
    and you wish to continue with hot upgrades, rollback to the previous version
    (X -1), cut a new release at version (X + 1), and deploy it. At this time
    you will be able to upgrade twice in a row `X - 1 => X => X + 1` and have a
    clean production instance.

To deploy a built upgrade release (using our previous example as a base):

    $ mkdir -p /opt/app/releases/0.2.0
    $ cp _build/prod/rel/myapp/releases/0.2.0/myapp.tar.gz /opt/app/releases/0.2.0/myapp.tar.gz
    $ pushd /opt/app
    $ bin/myapp upgrade 0.2.0

If the upgrade is not working properly, you can roll back to a previous version:

    $ bin/myapp downgrade 0.1.0

!!! warning
    You cannot downgrade to an arbitrarily old version, you must downgrade in
    the same order in which upgrades are applied, as the appup instructions must
    be applied in reverse order. In other words, to go from `0.5.0` to `0.3.0`,
    you must first downgrade to `0.4.0`, _then_ `0.3.0`
