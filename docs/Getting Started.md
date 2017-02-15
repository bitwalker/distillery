# Getting Started

Please take the time to review the output of `mix help release`, as well as other `release.*` tasks,
they cover more detail about usage at the command line, and what the various options mean.

Additionally, if you want to know what a certain configuration option does, you can find that information
on the [Configuration](https://hexdocs.pm/distillery/configuration.html) page.

## Installation/Setup

Simply add `distillery` to your dependencies, run `mix deps.get` and you are ready to start.

Within your project directory, you can then run `mix release.init` to setup your project with
a `rel` directory containing a release configuration file (`config.exs`). Take a look at the output
of `mix help release.init` to see how you can tweak this initial config file.

## Overview

To understand what various terms mean in the context of releases,
please review the [Terminology](https://hexdocs.pm/distillery/terminology.html).

There are two basic cases when building a release:

- Building a new release
- Building a release which upgrades a previously installed release

There is a great deal of granularity around how releases are defined, how to handle upgrades, and so on,
but that's the basic gist. Distillery provides a single command for both, but a flag to explicitly enable
the latter case, in other words:

```
# Build a release
> mix release

# Build an executable release
> mix release --executable [--transient]

# Build an upgrade release
> mix release --upgrade
```

From time to time, you may want to clean a previous release build, which you can do with `mix release.clean`.

If you want to remove all traces of distillery from your project, simply run `mix release.clean --implode`, and
remove it from your dependencies.

For more detail on building a release for a project, please see the [Walkthrough](https://hexdocs.pm/distillery/walkthrough.html)
doc. There is more detailed information on more advanced topics such as upgrades in other documents hosted here as well.
