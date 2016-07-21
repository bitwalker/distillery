# Runtime Configuration

There are differences in how you approach runtime configuration of your application
when using releases vs regular Mix projects. You still use your `config.exs`, but
there are caveats which apply:

- With releases, at runtime there is no longer any Mix project information, as your
  application is indistinguishable from any other Erlang application. This means your
  application should never use anything from the `Mix.*` namespace.
- Related to the above, it is not possible to use Mix tasks, generally speaking, you
  can include the `:mix` application in a release, but whether it works is uncertain at
  best, due to the fact that Mix is designed to be used in conjunction with the Mix project
  structure, and with a `mix.exs` available. Neither of which are true in releases.
- With Mix projects, your configuration is evaluated at runtime, so you can use
  functions such as `System.get_env/1` to conditionally change configuration
  based on the runtime environment. With releases, `config.exs` is evaluated at
  build time, and converted to a `sys.config` file. Using functions like
  `System.get_env/1` will result in incorrect configuration. Instead, you must configure
  your application so that if you need to fetch environment information at runtime, you
  can do so. See the Configuration Conventions section below for more information.

## Configuration Conventions

It is a common convention within the Elixir community to handle a `{:system, "VAR"}` tuple
which indicates to the application being configured that it should use `System.get_env/1` to
fetch that configuration value. This convention can be expanded to also accept a `{:system, "VAR", default}`
tuple so that you can provide sane defaults if the variable is not set in the environment.

This convention is so valuable, that I've provided a `Config` module below, which you can drop into
your application, and use in place of `Application.get_env/2`, and it will seamlessly handle both of the
conventions above for you. I've used it now in a number of applications, and have found it to make
my life much easier. I have considered making it a library on Hex, or adding it to `distillery`, but
it is so simple, that a simple gist seems more useful.

See [config.ex](https://gist.github.com/bitwalker/a4f73b33aea43951fe19b242d06da7b9) for the implementation.

## Configuration Tools

It may be the case that you are providing release packages to end users, who will need to configure the
application. These end users may even be your own internal ops team. They may or may not be familiar with
Erlang terms, and thus `sys.config` is a very poor configuration experience. In these situations you may
want to consider an alternative configuration tool I wrote, called [conform](https://github.com/bitwalker/conform).
It was designed specifically for use with releases, and with ease of use for end-users as the ultimate goal.

As a developer, you define a schema which maps simple configuration settings contained in an init-style `.conf` file,
into the specific structures required for your application's configuration. To see an example of what these look
like, [take a look here](https://github.com/bitwalker/conform/tree/distillery#conf-files-and-schema-files).

When you deploy your application, user simply modify the `.conf` file as needed, and run the release, `conform` handles
converting the configuration into runtime configuration for the release using the schema, and you can access that
configuration via `Application.get_env/2` as usual.
