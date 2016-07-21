# Walkthrough

**IMPORTANT**: Before starting, please review the [Terminology](https://hexdocs.pm/distillery/terminology.html)
page to get familiar with the terms used in this guide.

This is a simple guide on how to use Distillery and releases in general. We will cover the following:

- Adding Distillery to your project
- Initializing Distillery
- Configuring your release
- Building your release
- Deploying your release
- Building an upgrade release
- Deploying an upgrade

Let's get started!

## Adding Distillery to your project

Just add the following to your deps list in `mix.exs`:

```elixir
defp deps do
  [{:distillery, "~> 0.7"}]
end
```

The run `mix do deps.get, compile`, and you're ready to go!

## Initializing Distillery

To set up your project for releases, Distillery will create a `rel` directory in your
project root, all files related to releases will be in this directory.

Distillery also creates `rel/config.exs`, which is the configuration file you will use
to configure Distillery and your releases. Depending on your project type, it will create
an appropriate default release configuration, along with two environments, `:dev` and `:prod`,
with typical configuration for those two environments. You can leave this configuration untouched,
or modify it as desired. We will look at this file and discuss it's contents briefly, check out
[Configuration](https://hexdocs.pm/distillery/configuration.html) for more information on this file
and available settings.

To initialize Distillery, just run `mix release.init`.

**NOTE**: In this walkthrough, we're making the assumption that this is a non-umbrella application,
though there is no significant differences, see [Umbrella Projects](https://hexdocs.pm/distillery/umbrella-projects.html)
for more details on configuration specific to that setup.

## Configuring your release

The default configuration file will look like the following (comments stripped):

```elixir
use Mix.Releases.Config,
    default_release: :default,
    default_environment: :dev

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

Let's talk about what these settings do from top to bottom. See the Configuration page mentioned above
if you want to explore settings not covered in this guide.

```elixir
use Mix.Releases.Config,
    default_release: :default,
    default_environment: :dev
```

This loads the configuration macros required by Distillery, and sets a few optional global settings:
`default_release`, which specifies which release to build by default if one is not specified to `mix release`,
and `default_environment`, which specifies which environment to build by default if one is not specified to `mix release`.
If `default_release` is set to `:default`, then the first release definition in the file will be used.
If `default_environment` is set to `:default`, then an "empty" environment will be used, and the only settings used
will be those set within a `release` block.

```elixir
environment :dev do
  set dev_mode: true
  set include_erts: false
end
```

This creates an environment called `dev`, and configures a few settings which are optimal for quick iteration
during development. `dev_mode: true` will symlink compiled BEAM files into the release directory, instead of copying them,
which ends up being significantly faster. `include_erts: false` tells Distillery to not copy the Erlang Runtime System into
the release directory, and instead just use the system-installed ERTS.

```elixir
environment :prod do
  set include_erts: true
  set include_src: false
end
```

This creates an environment called `prod`, and configures a few settings which are optimal for a self-contained
production release package. `include_erts: true` bundles the Erlang Runtime System so that the target system need
not have Erlang or Elixir installed, and `include_src: false` will ensure that unnecessary source code files are not
included in the release package, reducing the final file size of the release.

```elixir
release :myapp do
  set version: current_version(:myapp)
end
```

This creates a new release definition, named `myapp`, and sets the only required setting for a release definition,
`version` to whatever the current version of the `myapp` application is when `mix release` is run, by using the
`current_version/1` macro.

You must have at least one release definition in the config. You do not have to create any environments, though the
example config does so for reference.

To recap, an environment is a group of settings which override those of a release when that environment is active, a
release is the specific configuration for a group of applications which will be packaged together. In a non-umbrella application,
it is usually the case that the release is named/versioned the same as the application being released. In umbrella applications,
this may or may not be true, depending on whether the umbrella is released per-app or as one. When building a release, the
release configuration is overlaid with the environment configuration, to form what is called a "profile". In simpler terms,
if you have a release named `myapp`, and an environment called `dev`, the profile would be `myapp:dev`.


## Building your release

Now that we've configured our application we can build it! Just run `mix release`. There are a few flags
to `mix release` that you may be interested in using right now:

- `--verbose`, will log every action performed by Distillery, this is important when debugging issues or reporting them
  on the tracker.
- `--name=<name>` to build a specific release from your config
- `--env=<env>` to build using a specific environment from your config
- `--profile=<name:env>` to build a specific combination of environment and release

See `mix help release` for a description of all flags.

When you run `mix release`, you should see something like the following:

```
==> Assembling release..
==> Building release myapp:0.1.0 using environment dev
==> You have set dev_mode to true, skipping archival phase
==> Release successfully built!
    You can run it in one of the following ways:
      Interactive: rel/test/bin/test console
      Foreground: rel/test/bin/test foreground
      Daemon: rel/test/bin/test start
```

As an example, building the release for the `prod` environment looks like this:

```
==> Assembling release..
==> Building release myapp:0.1.0 using environment prod
==> Including ERTS 7.3 from /Users/paulschoenfelder/erlang/18.3/erts-7.3
==> Packaging release..
==> Release successfully built!
    You can run it in one of the following ways:
      Interactive: rel/test/bin/test console
      Foreground: rel/test/bin/test foreground
      Daemon: rel/test/bin/test start
```

At this point, you can run your release using one of the three commands listed in the output.

## Deploying your release

**IMPORTANT**: When running `mix release` for deployment to production, you should set `MIX_ENV=prod`,
to avoid pulling in dev dependencies, and to make sure the compiled BEAMs are optimized.

**NOTE**: If you are deploying to a different OS or architecture than the build machine, you should
either set `include_erts: false` or `include_erts: "path/to/cross/compiled/erts"`. The former will
require that you have Erlang installed on the target machine, and the latter will require that you
have built/installed Erlang on the target platform, and copied the contents of the Erlang `lib`
directory somewhere on your build machine, then provided the path to that directory to `include_erts`.

Let's assume you've built your release with `MIX_ENV=prod mix release --env=prod` and
are ready to deploy it to production. The artifact you will want to deploy is the release
tarball, which is located at `rel/<name>/releases/<version>/<name>.tar.gz`. If you included
ERTS in the release, then you can simply copy this tarball to the target machine, extract it
with `tar -xzf <name>.tar.gz`, and run it with `bin/<name> start`. If you didn't include ERTS,
make sure you have installed Erlang first, and then you can proceed with deployment.

Some alternative approaches to builds so that you can bundle ERTS easily:

- Build the release in a Docker container running the same OS version and CPU architecture,
  then copy the tarball out of the container for deployment to the target.
- Install Erlang in a Docker container running the same OS version and CPU architecture,
  then copy the Erlang `lib` directory back to your build machine so that you can cross-compile your release.
- Same as the above, but use Vagrant

Personally, I recommend the "build in Docker" approach, as it's the easiest, and simple to setup.

The `start` command of the boot script will automatically handle running your release as a daemon, but
if you would rather use `upstart` or `supervisord` or whatever, use the `foreground` task instead.

Once started, you can connect a shell to the running release with `bin/<name> remote_console` or
`bin/<name> attach`, though I would avoid the latter unless you have good reason to use it, as exiting
with `CTRL+C` will kill the running node, while doing so with `remote_console` will simply exit the shell.

If started with `start`, you can run `stop` to shutdown the node. If started with `foreground`, you can send
an interrupt with `CTRL+C` or `kill` to shut it down gracefully.

## Building an upgrade release

**NOTE**: You do not have to use hot upgrades, you can simply do rolling restarts by running `stop`, extracting
the new release tarball over the top of the old, and running `start` to boot the release.

So you've made some changes and bumped the version of your app, and you want to perform a hot upgrade
of the target system. This is pretty simple!

- Run `mix release --upgrade` to build an upgrade release

You will now have a new tarball in `rel/<name>/releases/<upgrade_version>/` which you can use for the next step.

## Deploying an upgrade

This part is very straightforward:

- Copy the new tarball to `<deployment_root>/releases/<upgrade_version>/<name>.tar.gz`,
  where `deployment_root` is the directory where the old version of the release was deployed.
  The `releases/<upgrade_version>` directory won't exist, so make sure you create it first.
- Run `bin/<name> upgrade "<upgrade_version>"` to install the new version of the release and hot upgrade
  the node.

That's it! To downgrade to the previous version, run `bin/<name> downgrade "<old_version>"`. Be aware
that you can only downgrade to the release you upgraded from. To downgrade to an arbitrarily old release,
you must downgrade to each version between the current version and the desired version first.
