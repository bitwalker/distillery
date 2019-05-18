# Command line interface

Distillery is a command-line oriented tool, and has two primary modes of
interaction. First, via Mix tasks, when working within a Mix project. Secondly,
via shell scripts, which are part of the generated release, and are the primary
means by which you interact with that release.

## Mix tasks

Distillery provides the following Mix tasks:

  * `distillery.init` - for initializing Distillery within a new project
  * `distillery.release` - for building releases
  * `distillery.release.clean` - for cleaning up generated release artifacts
  * `distillery.gen.appup` - for generating appups to use in upgrade releases

For more information about these commands and their usage:

    $ mix help <task>

!!! tip
    If you are building releases as part of your CI/CD pipeline, you may want to use
    the `--warnings-as-errors` flag to the `release` task. This will prevent
    building releases which may fail at runtime from making it through the pipeline.
    **NOTE**: this `--warnings-as-errors` is not the same as the `compile` task `--warnings-as-errors`,
    if you want both, you should run `compile` first, then run `distillery.release`, passing
    the flag to both.

## Release tasks

Release tasks are commands given to the shell script which acts as the release
entry point, i.e. the `bin/myapp` script.

There are numerous tasks available, you have already seen a few of them:

  * `foreground` - run the release in the foreground, like `mix run --no-halt`
  * `console` - run the release with a shell attached, like `iex -S mix`
  * `start` - run the release in the background

There are a few other important tasks:

  * `stop` - stop a release started via `start`
  * `remote_console` - attach a shell to a running release
  * `describe` - print metadata about the release

To see a full listing of tasks available, run `bin/myapp` with no arguments.
