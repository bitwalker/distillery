# Terminology

Below is a list of words and their definitions as used within distillery, as well as more broadly
within the Elixir community, I will distinguish between them here.

## General Terms

#### Release

A release is a package of your application's .beam files, including it's dependencies .beam files,
a sys.config, a vm.args, a boot script, and various utilities and metadata files for managing the
release once it is installed. A release may also contain a copy of ERTS (the Erlang Runtime System).

#### Application

An application refers to an Erlang application, typically with a supervision tree, but not always,
as is the case with "library applications". They are tightly bound with the way OTP and releases work,
and thus are an important concept to understand.

#### sys.config

A static file containing Erlang terms, it is how configuration is provided to a release.

#### vm.args

A file which provides configuration to the Erlang VM when it starts a release.

#### Appup

A file containing Erlang terms which describes with high-level instructions how to upgrade and downgrade
between the current release and one or more older releases.

#### Relup

A file containing Erlang terms which describes with low-level instructions how to upgrade and downgrade
between the current release and one or more older releases.

#### Target System

Refers to the deployment host, or to an already installed release on that host.

## Distillery Terms

#### Release

Refers to both the general definition of release, as well as the metadata and configuration which applies
to the building of a release.

#### Environment

A named set of configuration settings which apply to all releases built for that environment. It differs
from Mix's environment, in that it refers to the target environment, not the build environment.

An environment's settings override those of a release.

#### Profile

A specific combination of release and environment configuration settings, after environment settings have
been merged over the release settings. When talking about profiles, it may be easier to do so by `{name}:#{env}`,
e.g. `myapp:staging` where `myapp` is the release name, and the environment is `staging`.

#### Overlay

When a release is constructed, and prior to it being archived, additional files or directories may be desired
in the release, and overlays are used to accomplish that. They consist of a few primitive operations: mkdir, copy,
link, and template, and allow you to do one of those four operations to extend the contents of the release as desired.

#### Boot Script

For lack of a better name, it is how we currently refer to the script executed when you run `bin/myapp <command>`.

#### Boot Hook

Pre/post events which execute associated scripts. By default, there are no hooks enabled, but you can provide
shell scripts in your configuration to enable them in a release.

#### Boot Command

When you run `bin/myapp foreground`, `foreground` is a boot command. Custom commands are like `foreground`,
things you can run from the boot script's environment to do things I haven't thought of yet.

#### Plugin

Plugins to `distillery` itself which execute at various points during the release build process, which allow you
to do things that are not easily accomplished with overlays and are not intended for runtime, and thus hooks/commands
are not a good fit. For example, one might write a plugin to convert a release into a Docker image, or an RPM package,
etc. You can use plugins to both setup and cleanup these types of things.
