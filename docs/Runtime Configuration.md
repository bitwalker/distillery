# Runtime Configuration

## config.exs & sys.config

There are differences in how you approach runtime configuration of your application
when using releases vs regular Mix projects. You still use your `config.exs`, but
there are caveats which apply:

- With releases, at runtime there is no longer any Mix project information, as your
  application is indistinguishable from any other Erlang application. This means your
  application should never use anything from the `Mix.*` namespace.
- Related to the above, it is not possible to use Mix tasks, generally speaking, you
  can include the `:mix` application in a release, but whether it works is uncertain at
  best, due to the fact that Mix is designed to be used in conjunction with the Mix project
  structure, and with a `mix.exs` available. Neither of which are true in releases. There is ongoing
  work on making this possible, but at this time it is a caveat. Look into [Custom Commands](https://hexdocs.pm/distillery/custom-commands.html)
  in the meantime.
- With Mix projects, your configuration is evaluated at runtime, so you can use
  functions such as `System.get_env/1` to conditionally change configuration
  based on the runtime environment. With releases, `config.exs` is evaluated at
  build time, and converted to a `sys.config` file. Using functions like
  `System.get_env/1` will result in incorrect configuration. Instead, you must configure
  your application so that if you need to fetch environment information at runtime, you
  can do so. See the Configuration Conventions section below for more information.

### Configuration Conventions

**NOTE:** It is no longer recommended to use the `{:system, "VAR"}` convention, as it has inconsitent
use in the community, and instead we'd rather push people towards an approach which works every time,
rather than only sometimes.

Instead the recommend approach to configuration is as follows:

- Provide default configuration in `config/config.exs`
- Provide configuration values known in advance for a given environment in `config/<env>.exs`
- For any runtime configuration, either set those values in the Application `start/2` callback, prior
to starting your supervisor tree, or in the `init/1` callbacks of individual supervisors/workers in your application.
You can use Elixir code to load configuration from wherever, and validate it closest to where it's used. It is recommended
that you create your own `Config` module which boxes up common validation/loading logic so that you can easily get config
values at runtime without cluttering up your `start/2` or `init/1` callbacks.

The above approach works for both release and deploy-source deployments, and so works the same everywhere. In addition,
it keeps configuration close to where it's cared about, and enables you to pick up configuration changes when you restart
parts of the application without needing to restart the whole release.

If you have dependencies which require runtime configuration, you can place them in `included_applications` and start them
as part of your supervisor tree, or with `Application.ensure_all_started(:app)` after configuring them. The former is recommended,
but the latter works as well.

### Configuration Tools

It may be the case that you are providing release packages to end users, who will need to configure the
application. These end users may even be your own internal ops team. They may or may not be familiar with
Erlang terms, and thus `sys.config` is a very poor configuration experience. In these situations you may
want to consider an alternative configuration tool I wrote, called [conform](https://github.com/bitwalker/conform).
It was designed specifically for use with releases, and with ease of use for end-users as the ultimate goal.

As a developer, you define a schema which maps simple configuration settings contained in an init-style `.conf` file,
into the specific structures required for your application's configuration. To see an example of what these look
like, [take a look here](https://github.com/bitwalker/conform#conf-files-and-schema-files).

When you deploy your application, users simply modify the `.conf` file as needed, and run the release, `conform` handles
converting the configuration into runtime configuration for the release using the schema, and you can access that
configuration via `Application.get_env/2` as usual.

## vm.args

This file is how you configure the Erlang runtime for your release. By default, it sets up the VM in distributed mode
with the name set to `<release_name>@127.0.0.1`, and the cookie set to `<release_name>`. This is how we are able to
remote shell to the node once it's started.

For a complete list of flags you can use in `vm.args`, see [here](http://erlang.org/doc/man/erl.html).

However, as is often the case, you may want to dynamically configure the name of the node (when clustering) and/or
the cookie (for security), as well as other settings based on values provided via environment variables. You can do
so by setting `REPLACE_OS_VARS=true` and then using `${VAR_NAME}` in the `vm.args` file.

If you are uncertain where the default `vm.args` is located, you may find it under `releases/<version>/vm.args`.

You may also provide your own config directory where your custom `vm.args`, `sys.config`, and potentially other
configuration files will be loaded from, by setting `RELEASE_CONFIG_DIR=path/to/files`. By default this will be set
to the root directory of the release, i.e. the folder to which you extracted the tarball. If `vm.args` or `sys.config`
cannot be found in `RELEASE_CONFIG_DIR`, it will fall back to using the ones under the `releases/<version>` directory.

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
environment variable at the time of running `mix release`.

For a complete list of environment variables respected by `run_erl`, see
[here](http://erlang.org/doc/man/run_erl.html).

