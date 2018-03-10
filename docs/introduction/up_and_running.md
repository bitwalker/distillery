# Up and Running

## Installation

First, you will want to add Distillery as a dependency to your project, and then fetch
dependencies with `mix deps.get`:

```elixir
# mix.exs
defp deps do
  [
    {:distillery, "~> 2.0"}
  ]
end
```

## Setup

Now that Distillery is installed, you need to perform a one-time setup to create the configuration
file you will use for defining releases and environments for your application.

```
mix release.init
```

There are a few options you can provide to this task, to view those just run `mix help release.init`.
The main option of interest is in regards to umbrella projects, as the default configuration is to define
a release containing all of the applications in the umbrella, but you may want to instead have it generate
a release for each initially. In either case, it does not matter much, as you will likely want to modify them
later anyway.

Running this task will generate a new directory `rel` in the root of your project, and a new config file,
`rel/config.exs` which is where you will define releases and environment-specific release configuration. An
example of what this looks like is shown below:

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
can find out more about these under [Release Configuration](../release_configuration.md).

## Building a release

We'll explore this in more detail later on, but to get a sense of how simple it is to get started, let's
build a basic release for experimentation:

```
> mix release                                                                                                  18:43:31
==> Assembling release..
==> Building release myapp:0.1.0 using environment dev
==> You have set dev_mode to true, skipping archival phase
==> Release successfully built!
    You can run it in one of the following ways:
      Interactive: _build/dev/rel/test/bin/myapp console
      Foreground: _build/dev/rel/test/bin/myapp foreground
      Daemon: _build/dev/rel/test/bin/myapp start
```

Since `MIX_ENV=dev` by default when running mix tasks, this used the `:dev` environment configuration when
building this release, which by default sets `dev_mode: true`, symlinking rather than copying content into
the release, and skipping the part where it is packed up into a tarball. As shown above, you can easily run
the release using one of the three different modes of execution.

Now that you have a basic idea of how Distillery works, let's back up a bit, and review what OTP releases are
and why they are important.

[Understanding Releases](understanding_releases.md)
