# Plugins

Plugins are how you extend `distillery` itself during release generation. It is worth your time
to review the module documentation for `Mix.Releases.Plugin` for more detailed information,
including an example plugin.

The plugin system executes the following callbacks in modules extending the `Mix.Releases.Plugin`
behaviour.

### before_assembly

Executed prior to the release being assembled. Use this to generate files, etc. before the release
process begins. This callback receives a `Release` struct, fully configured.

### after_assembly

Executed after the release is assembled in `rel/<release_name>`, but prior to being archived. Useful
if you want to manipulate the release in some way after assembly. This callback also receives a
`Release` struct.

### before_package

Executed just prior to archival of the release. Useful for adding things to the release which are not
trivially done with overlays. This callback also receives a `Release` struct.

### after_package

Executed after the release has been archived. Useful for doing post-processing type events, i.e. building
a Docker image, etc. Could also be used to automate deployments.

### after_cleanup

Executed after a release has been cleaned. Useful if your plugin needs to clean up files which may not
have been removed by the primary clean task. This callback will receive a list of strings, which are the
arguments as passed to `mix clean` on the command line, unprocessed so that you can pass them to `OptionParser`.
