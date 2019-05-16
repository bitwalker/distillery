# Release Plugins

Plugins are how you extend `distillery` itself during release generation. It is worth your time
to review the module documentation for `Distillery.Releases.Plugin` for more detailed information,
including an example plugin.

Plugins can be defined as either a part of your application code, or in Elixir modules contained
in `.exs` files under `rel/plugins`. The latter will be automatically imported for you so that you
can reference them in the configuration.

You add plugins to a release or environment like so:

```elixir
environment :prod do
  plugin MyApp.ProdPlugin
end

release :myapp do
  ..snip..
  plugin MyApp.DoStuff
end
```

Plugins can be configured by passing options to the `plugin` macro:

```elixir
plugin MyApp.AwesomePlugin, foo: 1, bar: 2
```

These plugins are expected to adhere to the `Distillery.Releases.Plugin` behaviour.

### before_assembly

Executed prior to the release being assembled. Use this to generate files, etc. before the release
process begins. This callback receives a `Release` struct, fully configured and options.

### after_assembly

Executed after the release is assembled in `output_dir`, but prior to being archived. Useful
if you want to manipulate the release in some way after assembly. This callback also receives a
`Release` struct and options.

### before_package

Executed just prior to archival of the release. Useful for adding things to the release which are not
trivially done with overlays. This callback also receives a `Release` struct and options.

### after_package

Executed after the release has been archived. Useful for doing post-processing type events, i.e. building
a Docker image, etc. Could also be used to automate deployments.

### after_cleanup

Executed after a release has been cleaned. Useful if your plugin needs to clean up files which may not
have been removed by the primary clean task. This callback will receive a list of strings, which are the
arguments as passed to `mix clean` on the command line, unprocessed so that you can pass them to `OptionParser` and options.
