# Terminology

Distillery uses terminology from both Erlang/OTP documentation, as well as some
terminology of it's own for concepts it has introduced. These terms are broken
up into two sections below for easier navigation. You should familiarize
yourself with these terms, at least briefly, to better understand the documentation.

## General terms

### Release

An OTP release is a package containing one or more applications, in their compiled form (i.e. BEAM files),
along with various metadata files, such as `vm.args`, configuration files, boot scripts, and management
scripts in the form of shell or batch files, depending on your platform. Releases may also contain the
Erlang Runtime System (ERTS) it depends on.

### Application

Application in our context refers to an OTP application, which may or may not define a supervision tree.
An application with a supervision tree is just referred to as an OTP application, and an application which
does not define a supervision tree, is typically referred to as a library application, as it provides a "library"
of modules for other applications to use - but both types are equivalent as far as the runtime system is concerned.

Your Mix project will define a single application, unless it is an umbrella project, in which case you will likely
have multiple applications. You should consider applications to be completely external, as if they are third-party
dependencies, and avoid calling into their internals, but rather only consume their public API. If you violate these
boundaries, you may find yourself in a situation where application code fails at runtime because modules are not yet
loaded, or processes not yet started.

### sys.config

A static file containing Erlang terms, it is one way configuration can be provided to a release.

### vm.args

A file which provides configuration to the Erlang VM when it starts a release.

### config.exs aka Mix.Config

The typical way you provide runtime configuration to an Elixir project which is not already handled by application
code. I strongly recommend you read [Runtime Configuration](../config/runtime.md) to understand how to best
handle configuration in your projects.

### Appup

A file containing Erlang terms which describes with high-level instructions how to upgrade and downgrade
between the current release and one or more older releases.

### Relup

A file containing Erlang terms which describes with low-level instructions how to upgrade and downgrade
between the current release and one or more older releases.

### Target system

Refers to the deployment host, or to an already installed release on that host.

## Distillery terms

### Release

Refers to both the general definition of release, as well as the metadata and configuration which applies
to the building of a release.

### Environment

A named set of configuration settings which apply to all releases built for that environment. It differs
from Mix's environment, in that it refers to the target environment, not the build environment.

!!! info
    An environment's settings override those of a release.

### Profile

A specific combination of release and environment configuration settings, after environment settings have
been merged over the release settings. When talking about profiles, it may be easier to do so by `{name}:#{env}`,
e.g. `myapp:staging` where `myapp` is the release name, and the environment is `staging`.

### Overlay

When a release is constructed, and prior to it being archived, additional files or directories may be desired
in the release, and overlays are used to accomplish that. They consist of a few primitive operations: mkdir, copy,
link, and template, and allow you to do one of those four operations to extend the contents of the release as desired.

### Appup transform

A plugin for Distillery's appup generation which transforms the appup instruction set in some way.

### Management script or run control (rc) script

This is the script executed when you run `bin/myapp`. It delegates to one or more scripts internally to execute
specific commands, including custom commands and hooks you define.

### Boot script

The script containing instructions for the VM on how to boot. The source form has the `.script` extension, and the
"compiled" or binary form of the script has the `.boot` extension. You can get the source form from the binary form
by piping it through `:erlang.binary_to_term/1`.

### Boot hook

Pre/post events which execute associated scripts. By default, there are no hooks enabled, but you can provide
shell scripts in your configuration to enable them in a release.

### Custom command

When you run `bin/myapp foreground`, `foreground` is a command. Custom commands are, like `foreground`,
things you can run from the management scripts environment to do things I haven't thought of yet.

### Plugin

Plugins to Distillery itself which execute at various points during the release build process, which allow you
to do things that are not easily accomplished with overlays and are not intended for runtime, and thus hooks/commands
are not a good fit. For example, one might write a plugin to convert a release into a Docker image, or an RPM package,
etc. You can use plugins to both setup and cleanup these types of things.
