# Using Distillery With Phoenix

**IMPORTANT**: Before starting, please review the [Terminology](https://hexdocs.pm/distillery/terminology.html)
page to get familiar with the terms used in this guide.

This is a simple guide on how to use Distillery with a production
config with [Phoenix](http://www.phoenixframework.org/). Here we will cover:

- Configuring your release
- Building your release

It is expected that you will have:

- a working Phoenix application
- a working `config/prod.exs`
- a _build environment which matches your production environment_
- your static asset path is the default `priv/static`
- Have reviewed the [Advanced Deployment Guide](https://phoenixframework.org/docs/advanced-deployment)

**NOTE**: It does not make much sense to cut a release for a `dev`
configuration with Phoenix, so this guide assumes you are interested
in `prod` releases. If you do build a release in `dev`, then you must also ensure
that you set `code_reloader: false` in your configuration. If you do not, you'll get a failure
at runtime about being unable to start `Phoenix.CodeReloader.Server` because it depends on Mix,
which is not intended to be packaged in releases. As you won't be doing code reloading in a release
(at least not with the same mechanism), you must disable this.

Let's get started!

## Adding and Initializing Distillery

Please refer to the [Initialization](https://hexdocs.pm/distillery/walkthrough.html#adding-distillery-to-your-project) section of the Distillery Walkthrough

## Configuring your Release

Configure your prod environment. Notice that there are a few
differences from the standard Distillery walk-through; namely the
`server`, `root`, and `version` options.

*file: config/prod.exs*
```elixir
config :phoenix_distillery, PhoenixDistillery.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "localhost", port: {:system, "PORT"}], # This is critical for ensuring web-sockets properly authorize.
  cache_static_manifest: "priv/static/manifest.json",
  server: true,
  root: ".",
  version: Mix.Project.config[:version]
```

Let's discuss each of these options.

- `server` configures the endpoint to boot the
  [Cowboy](https://github.com/ninenines/cowboy) application http
  endpoint on start.
- `root` configures the application root for serving static files
- `version` ensures that the asset cache will be busted on *versioned*
  application upgrades (more on this later)

## Building your release

Building a Phoenix release requires that your static assets are built
(that they are properly consolidated and placed somewhere where
phoenix knows how to serve them).  A production release requires 3
steps:

1. `./node_modules/brunch/bin/brunch b -p` build's your assets in
   production mode. More detail can be found in the
   [Phoenix Static Asset Guide](http://www.phoenixframework.org/docs/static-assets)
1. `MIX_ENV=prod mix phoenix.digest` To compress and tag your assets
    for proper caching. More detail can be found in the
    [Phoenix Mix Task Guide](http://www.phoenixframework.org/docs/mix-tasks#section--mix-phoenix-digest-)
1. `mix release --env=prod` To actually generate a release for a
    production environment

There are some optional flags available to you as well:

- `--verbose`, will log every action performed by Distillery, this is
  important when debugging issues or reporting them on the tracker.
- `--name=<name>` to build a specific release from your config
- `--upgrade` to build an upgrade release for hot upgrading an
  application (more on this later)

See `mix help release` for a description of all flags.

As an example, building the release for the `prod` environment using
`mix release --env=prod` looks like this:

```
==> Assembling release..
==> Building release myapp:0.0.1 using environment prod
==> Including ERTS 8.0.2 from /usr/local/Cellar/erlang/19.0.2/lib/erlang/erts-8.0.2
==> Packaging release..
==> Release successfully built!
    You can run it in one of the following ways:
        Interactive: _build/dev/rel/myapp/bin/myapp console
        Foreground: _build/dev/rel/myapp/bin/myapp foreground
        Daemon: _build/dev/rel/myapp/bin/myapp start
```

At this point, you can run your release using one of the three
commands listed in the output.

## Deploying your release

Please refer to the [Deployment](https://hexdocs.pm/distillery/walkthrough.html#deploying-your-release) section of the Distillery Walkthrough
