# Handling Configuration

One of the things you may have heard about deploying releases is that
configuration is hard. This was never exactly completely true, but in
previous iterations of the release tooling, it was certainly more difficult to
deal with some edge cases; particularly dealing with applications that abuse the
application env for configuration, rather than using parameterized processes and
functions. This pain was due to the fact that Mix's config file, `config.exs`,
was not usable directly in releases.

## Background

Releases instead required a `sys.config` file, essentially a static form of
configuration defined in Erlang syntax. In order to build releases for Elixir
applications, older tooling compiled the results of evaluating the Mix config
file to `sys.config` format, and bundled that into the release.

This meant that some constructs for runtime configuration, namely dynamic
things, like `System.get_env/1` would be evaluated at build time, not runtime,
which was a source of confusion. Older tools introduced `REPLACE_OS_VARS`, an
environment variable you export at runtime which instructed the tool to replace
occurances of `${VAR}` with the value from the system environment in the
`sys.config` file.

The problem with `REPLACE_OS_VARS` is that it's essentially a hack, and as such
had limitations - you could only use the `${VAR}` syntax in strings, because
otherwise Mix couldn't evaluate the config. The result is that you could only do
"dynamic" configuration with string values, and not values of other types.

This was generally only a problem with applications that were not well behaved
with regard to configuration - but sometimes you can't choose your dependencies,
and so a solution was still needed.

## Included Applications

One approach to working around the problem of configuring an application needing
dynamic configuration at boot is adding it to `:included_applications`.
Applications in this list are not automatically started by the runtime, instead
it is up to your application to start them as part of your supervision tree.
Doing so allows you to perform some work before that application is started,
namely configuration.

The downside of `:included_applications` is that an application can only be
included once, and any applications which depend on it being started must also
be included, or they will never start and your application will never start,
leading to a chicken and egg problem where you can't start the included
application because your app can't start because the included application isn't started!

In general this approach should be reserved for when it is the only solution, or
when your application truly needs to control the lifecycle of the included
application. Usually this only applies to applications within your stack, not dependencies.

## Alternative Tools

There were a variety of tools which were born out of the need to work around
runtime configuration of poorly designed applications. One of which I wrote,
called [Conform](https://github.com/bitwalker/conform). Libraries like this
worked as release plugins, manipulating the `sys.config` file via hooks at
runtime to inject custom configuration.

While such tools work, they are inherently fragile, as they needed to do
orchestration via shell scripts to properly handle replacing configs without
destroying originals, playing nice with upgrades, and integrating with some of
the release tooling's implicit behavior. Ideally we wanted something that was
integrated at the same level as the `sys.config` mechanism itself.

## Config Providers

In 2.0+, Distillery provides a framework for loading configuration at runtime
from sources other than `sys.config`, called Config Providers. Providers are
just modules which implement a behavior, and are configured via
`rel/config.exs`. You can have no config providers (using just `sys.config`) or
many providers (running in order and applying configuration on top of the last).

Config providers are executed prior to boot, and the resulting application env
is then persisted to a final `sys.config`, which is then used by the release itself.

Config providers can be used by adding the provider module and its
configuration to `rel/config.exs` like so:

```elixir
environment :prod do
  set config_providers: [
    {Toml.Provider, [path: "${RELEASE_ROOT_DIR}/config.toml"]}
  ]
  set overlays: [
    {:copy, "config/defaults.toml", "config.toml"}
  ]
end
```

The above (using the provider from
[toml](https://github.com/bitwalker/toml-elixir)) instructs Distillery to modify
the boot script for the release to execute the provider with
`Toml.Provider.init([path: "..."])`. If you
are wondering how to get a config file in the release, the above example also
shows how you might use an overlay to copy a default config file into the
release, to a location which will not overwrite a previous config when the
release is extracted, but will be handy when configuring the release for the
first time.

Any provider module must implement the `Distillery.Releases.Config.Provider` behavior.
See its documentation for details.

This configuration framework supports a variety of interesting configuration
scenarios, such as reading from files like `.toml`, `.yaml`, or `.json`; using
`:httpc` to request configuration from a metadata endpoint like etcd or Consul.

## Mix Config Provider

Out of the box, Distillery also includes a provider for `Mix.Config`, which
allows you to use `config.exs` files with a release. You have to opt in to
this provider, because `Mix.Config` blends compile-time and runtime
configuration options into one file, and many legacy configs make assumptions
about the environment the config is evaluated in (namely that a Mix project is
available, or that commands like `git` can be invoked and have meaningful
output). You can use it like so:

```elixir
environment :prod do
  set config_providers: [
    {Distillery.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/config.exs"]}
  ]
  set overlays: [
    {:copy, "rel/config/config.exs", "etc/config.exs"}
  ]
end
```

You may notice above that I'm pulling in a Mix config from
`rel/config/config.exs`, this is the recommended way to deal with runtime
configuration using `Mix.Config`; create a dedicated config which handles
fetching runtime configuration _only_, and place it in `rel/config`. Use the
standard `config/*.exs` files for compile-time configuration (of course, feel
free to use `dev.exs` or it's equivalent for development runtime config).

You _can_ copy configs straight from `config/`, but I would avoid doing so.

## Alternative Configuration

There are some additional methods for providing configuration, either for the VM
or for applications:

### Option 1: erl_opts

One approach is to provide configuration via `:erl_opts`:

```elixir
environment :prod do
  set erl_opts: "-kernel sync_nodes_mandatory '[foo@hostname, bar@hostname]'"
end
```

This works well for simple config values, but is unwieldy for complex values
(such as the example above).

### Option 2: vm.args

Another approach is to set config flags via `vm.args`:

```elixir
environment :prod do
  set vm_args: "rel/prod.vm.args"
end
```

```
# prod.vm.args
-kernel sync_nodes_mandatory '[foo@${HOSTNAME}, bar@${HOSTNAME}]'
```

This approach is a much better way of handling arguments to the VM during boot.
And with `REPLACE_OS_VARS=true` exported in the runtime environment, values can
even be dynamic, as shown in the example above, where `${HOSTNAME}` would be
replaced with the value of the system `HOSTNAME` environment variable.

The downside is that it still relies on some degree of static information, e.g.
the nodes in the `sync_nodes_mandatory` list above are known in advance in the
example, but what about when the node names are not known?

### Option 3: Runtime Generation

If none of the above are workable solutions, you are likely in a situation where
you will need to construct `vm.args` or `sys.config` dynamically as part of your
deployment, or using boot hooks like `pre_configure`. You would do something
like the following:

```elixir
environment :prod do
  # The template for vm.args
  set vm_args: "rel/prod.vm.args"
  # The hook to mutate the template
  set pre_configure_hooks: "rel/hooks/pre_configure.d"
end
```

```
# prod.vm.args
-kernel sync_nodes_mandatory '[${SYNC_NODES_MANDATORY}]'
```

```bash
#!/usr/bin/env bash
# hooks/pre_configure.d/generate_vm_args.sh

export SYNC_NODES_MANDATORY

if [ -z "$HOSTNAME" ]; then
  echo 'Expected $HOSTNAME to be set in the environment, unable to configure mandatory nodes!'
  exit 1
fi

# If no nodes defined, set it to an empty list
if [ -z "$NODES"]; then
  SYNC_NODES_MANDATORY=""
else
  # Expects $NODES to be something like 'foo,bar,baz'
  for node in `echo "$NODES" | sed -e s/,/\n/g`; do
    if [ -z "$SYNC_NODES_MANDATORY" ]; then
      # If no nodes defined yet, adding the first
      SYNC_NODES_MANDATORY="\\'${node}@${HOSTNAME}\\'"
    else
      # Otherwise append an element to the list with ,
      SYNC_NODES_MANDATORY="${SYNC_NODES_MANDATORY},\\'${node}@${HOSTNAME}\\'"
    fi
  done
fi
```

This setup above will generate, at runtime, a final `vm.args` that looks
something like the following, given `NODES="foo,bar,baz"` and `HOSTNAME=host.local`:

```
-kernel sync_nodes_mandatory '[\'foo@host.local\',\'bar@host.local\',\'baz@host.local\']'
```

### Option 4: Configuration Management

Last, but not least, using configuration management systems like Salt, Puppet,
Chef, Ansible, etc., are great ways to handle generating the `vm.args` or other
configuration files during deployment. They typically have better templating
tools so that you don't have to write something from scratch in shell.

If this is an option for you, I would start here before reaching for any of the
above options.

### Wrap up

As you can see, there are a variety of ways to configure your release at
runtime. In general, you should reach for config providers for app config, and `vm.args`
for VM config - if those approaches aren't viable, one of these others may work
for you.

## Configuring Applications

Lastly, I want to provide some general guidance on designing your applications
to be easily configurable when used as a component in a larger system.

### Rule 1: Parameters, not environment

If you need some piece of configuration, and you are wondering how best to
handle getting it to where it is needed, always try to pass configuration as
parameters first, rather than using the application environment (e.g.
`Application.get_env/2`).

#### Non-OTP Applications

For non-OTP applications, this is simple, have all your API functions which
require configuration, accept a list of options as a parameter, and pass it down
the stack to where it's needed.

You can make this parameter default to an empty list, or some predetermined set
of defaults with `opts \\ []` or `opts \\ @defaults`, like so:

```elixir
defmodule Log do
  @default_device :standard_io
  @default_opts [device: @default_device]

  def info(msg, opts \\ @default_opts) do
    device = Keyword.get(opts, :device, @default_device)
    IO.puts(device, msg)
  end
end
```

In the example above, users of this API can use `Log.info(msg)` for the most
part, unless they need to change the defaults. In cases where you can't accept a
default, require the extra parameter, or use `Keyword.fetch!/2` to raise an
error if an option was not provided.

#### OTP Applications

For OTP applications, parameterization starts at the root of your application,
in the application callback module, namely in the `start/2` callback:

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__.Supervisor)
  end

  def init(_) do
    all = Application.get_all_env(:myapp)
    config = [
      port: get_in(all, [__MODULE__.Component, :port]) || System.get_env("PORT"),
      # ...
    ]
    children = [
      {__MODULE__.Component, [config]},
      # ...
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

In the above example, our application will fetch configuration from the
application environment, but then build up the actual configuration which will
be passed to children of the root supervisor by first looking for a value in the
application env, then falling back to other methods. Once constructed, this
configuration is passed down the supervision tree, from parent to child,
starting at the root.

This approach can be extracted into a `MyApp.Config` module, where you can put
all the logic for fetching configuration and converting it into it's final form,
keeping your application callback module clean.

An additional benefit of this approach is that in your tests, you can start many
copies of `__MODULE__.Component` with different configuration, allowing you to
test that component in parallel. This requires taking an approach to designing
your processes so that they are not relying on singletons or other global state,
but the very first step is taking configuration as parameters.

#### "A la carte" OTP Applications

This approach to designing applications is similar to what I just described, but
your application callback module does not actually start any children. Instead,
users of your application start things like `__MODULE__.Component` within their
own supervision tree, and take over responsibility for providing configuration
via parameters.

You may still have need for some global state, or singleton processes, which do
not require configuration, and are invisible to users of your application. In
these cases your application callback module will start _only_ these children,
and leave the rest up to users of the application. You can see this approach in
action in the Postgrex library, for example.


## run\_erl

The `run_erl` command is responsible for running a release on Unix systems,
capturing STDERR and STDOUT so that all output can be logged as well as
allowing monitoring and remote debugging of a running release.

Several environment variables are useful in configuring `run_erl`, for
example to customize logging output.  To specify environment variables to
apply to `run_erl`, you can add a line like
`set run_erl_env: "RUN_ERL_LOG_MAXSIZE=10000000 RUN_ERL_LOG_GENERATIONS=10"`
in your release configuration.

This configuration can also be specified in the `RUN_ERL_ENV`
environment variable at the time of running `mix distillery.release`.

For a complete list of environment variables respected by `run_erl`, see
[here](http://erlang.org/doc/man/run_erl.html).
