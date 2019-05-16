# Frequently Asked Questions

!!! info
    If you have a question that you think belongs in this section, please open
    an issue [here](https://github.com/bitwalker/distillery/issues/new). We will
    gladly accept PRs for documentation as well!

## Release Configuration

### What is the difference between Mix environments and Distillery environments?

While similar on the surface, the concept of environments in Mix and Distillery
refer to two different things.

In Mix, environments refer to the _compilation_ environment. Mix environments
determine what dependencies are fetched and compiled, what tasks are available,
and potentially affect how your project and its dependencies compile themselves,
for example, setting different values for module attributes based on `Mix.env`.

Since Mix blends compile-time and runtime concerns in it's config file,
`config/config.exs`, Mix environments also potentially affect which
configuration values are set at runtime. You will see this in practice with
something like `import_config "#{Mix.env}.exs"`.

Distillery, on the other hand, refers to environments in a deployment context,
e.g. staging, production, etc. In development, you want builds to be optimized
for quick iteration, or to use system tooling rather than bundle everything
needed into the release. In staging or production, you will want to build an
artifact that stands alone, but may want to change how configuration is
provisioned in those environments.

In many cases, your Mix environments and Distillery environments may line up -
which is why Distillery creates `:dev` and `:prod` environments by default in
its configuration file, and why it sets the default environment to be chosen based on
the value of `Mix.env`. This allows you to run `mix distillery.release` or `MIX_ENV=prod
 mix distillery.release` out of the box, and have it do "the right thing".

You can either keep your Mix environments and Distillery environments in sync,
or select them independently:

    $ MIX_ENV=prod mix distillery.release --env=staging

### What is a profile?

Distillery refers to the pairing of a release definition with an environment as
a profile, or release profile. Internally a profile is the result of overlaying
environment-specific settings on top of settings in the release definition.

You can select a specific release/environment pair to build with the `--profile` flag:

    $ MIX_ENV=prod mix distillery.release --profile=myapp:staging

Which is the same as if you had invoked `release` like so:

    $ MIX_ENV=prod mix distillery.release --name=myapp --env=staging

### Warnings

### "Orphaned" applications or partially booted releases

Distillery allows you to specify the start type of applications in the release,
or override the start type, like so:

```elixir
release :myapp do
  set applications: [
    myapp: :permanent,
    foo: :temporary,
    bar: :load,
    qux: :none
  ]
end
```

Using the above example, let's assume that `:bar` is a dependency of `:myapp`,
and is present in the `applications` list of `:myapp`.

When the release boots, it starts all the applications in the release, in
dependency order. It determines this order based on the `applications` list for
each application being started. Before an application can be started, all
applications in its `applications` list must be started first.

So using our example, when the release boots, and reaches the point where it
wants to start `:myapp`, it will wait for `:bar` to start before proceeding.
However, we set the start type of `:bar` to `:load`, which means it isn't
started during boot, and the release will wait indefinitely for a
condition which will never happen - it will only be partially booted. 

!!! info 
    The result in this situation is that the release will appear to have
    started without errors, but you will notice missing functionality. For
    example, if `:myapp` is a Phoenix application, the HTTP endpoint will never
    be started, and so requests will fail.

Distillery will warn you when it detects this situation, allow you to fix the
start type, or take a different approach with how you manage the load-only
dependency. Usually, the solution is to make `:bar` an included application, and
remove it from the `applications` list in `rel/config.exs`.

!!! warning
    It is not strictly a problem to use `:load` or `:none` start types, but they
    must not be used when they are dependencies of an application with a start type of
    `:permanent` or `:temporary`, as those applications will be unable to boot.
    Do not specify a start type if the application is included (in other words,
    present in `included_applications`).

## Usage

### How do I build a self-contained executable?

Distillery has the capability to generate "executable" releases via the `--executable` flag.

These are self-extracting tar archives with a header script which passes
arguments to the releases run control script upon extraction. It will only
extract itself on the first run, to `./tmp/<rel_name>`, further runs will use
the already extracted release for efficiency. If you want the executable to
remove the extracted files after the release terminates, you can enable this
auto-cleanup by marking the executable as transient with `--transient`.

!!! warning
    The executable feature is unavailable on Windows

This feature is ideal for building command-line applications. The reason why you
might want to use this approach versus escripts is that you are able to bundle
the Erlang runtime with the executable, and thus deploy the app to target
systems which do not have Erlang/Elixir installed, additionally, you have the
flexibility to use these applications as daemons with all of the tooling
associated with releases (e.g. remote shell).

### How do I run multiple instances of a release on the same host?

You may have seen an error something like this:

```erlang
{error_logger,{{2016,8,26},{23,11,6}},"Protocol: ~tp: the name myapp@127.0.0.1 seems to be in use by another Erlang node",["inet_tcp"]}
```

This occurs when a fully-qualified node name is already running on the host.

Distillery creates releases which have a preset name and cookie for Erlang's
distribution protocol. As a result, every time you start the release, it has
the same fully-qualified node name. To work around this, you just need to
provide your own VM arguments file in place of the defaults that Distillery provides.

First, create `rel/vm.args`:

    -name ${NODENAME}@127.0.0.1
    -setcookie myapp

This uses syntax for replacing environment variables at runtime, enabled by
exporting `REPLACE_OS_VARS` in the runtime environment (as well as any
environment variables you reference).

Then, update your `rel/config.exs` to use that custom `vm.args`, which should
look something like the following:

```elixir
release :myapp do
  set version: current_version(:myapp)
  set vm_args: "rel/vm.args"
end
```

!!! tip
    You can set `:vm_args` in either release or environment definitions.

Then run your release:

    $ REPLACE_OS_VARS=true NODENAME=myapp1 bin/myapp start
    $ REPLACE_OS_VARS=true NODENAME=myapp2 bin/myapp start
    $ REPLACE_OS_VARS=true NODENAME=myapp3 bin/myapp start

## Source Control

### What should I put in my .gitignore?

You should make sure that `rel` is **not** in your `.gitignore`, as everything
under that directory should be considered required sources for release builds.

!!! tip
    If you change the release output directory via the `:output_dir` setting,
    then you will want to ensure that the new directory _is_ ignored, since outputs can
    always be reproduced from the sources.

## Errors

### Release crashes with undefined module errors

If you, or a dependency, forgot to include an application in your `applications`,
`extra_applications`, or `included_applications` lists (when not relying on
Mix's inference), then your release will crash at runtime, the first time code
in that application is referenced.

To fix this, you must do one of the following:

  * For Erlang standard library applications, for example `xmerl`, you must add
    the application to `extra_applications`.
  * For dependencies pulled from Hex, or an SCM, if the missing application is a
  direct dependency and you manually define your `applications` list in
  `mix.exs`, you need to add the missing application to that list.
  * If the missing application is a transitive dependency (in other words, a
  dependency of a dependency), then you have three options:
    * Add the application to the parent dependency's `applications` list
    * Make the dependency a direct dependency, as an override (e.g. `{:foo, "~>
      0.1", override: true}`), and add it to your `applications` list (if not
      relying on inference)
      
!!! tip
    If you discover a dependency with missing applications in it's
    `applications` list, you should notify the maintainer, as this is a bug in
    their application!

Distillery used to warn about this condition, but in order to do so, it relied
on private Mix APIs. We did this because the way Mix inferred the
`applications` list was not always correct with regard to the `runtime: false`
option of dependencies - namely that if a dependency appeared in `applications`
and was decorated with `runtime: false`, Mix would ignore the `runtime: false`
declaration. These two settings are mutually exclusive, so Distillery warned
about this when there was conflict.

These issues are now being addressed upstream in Mix, so this should no longer
be an issue in general, but if you do encounter a problem with `applications`
inference, it should be reported upstream in Mix.

### I have two dependencies with conflicting modules

This is an annoying situation to find yourself in, and is a key reason why the
community has a convention of namespacing modules. However, if you encounter this
situation in your own projects, the first step is to fork one (or both)
projects, namespace the problem modules, and then use your fork until the author
of the project merges your changes.

!!! tip
    If you encounter problems with any of your dependencies, always open an
    issue! Most maintainers are glad to fix issues causing grief to their users,
    and issues like the one mentioned here have widespread impact. It is always
    worth the time to write up an issue so that the community can benefit as a whole.

It is critical that we as a community let maintainers know when they have modules which
conflict with other projects, and encourage each other to namespace our projects properly
to prevent this from happening.


## NIFs (natively-implemented functions)

If you forget to compile NIFs on the same OS/architecture as your target system, your release
will fail at runtime when it attempts to load them. You must cross-compile your release in that case,
or ensure that your build environment and target environment share the same OS/architecture, and system
packages.

Cross-compiling a release with `include_erts: <path>` *only* cross-compiles the BEAMs, it does not
cross-compile any natively-implemented dependencies, such as those contained in `comeonin` and other packages.

!!! warning
    You must also make sure that the Erlang runtime (ERTS) is compiled for the
    target system as well, or it will fail to boot. Distillery will tell you (at
    runtime) if the ERTS it tries to run with does not work on the target system.

If you must cross-compile, you will need to make sure that you set up the cross-compilation toolchain for
those dependencies as well, which is beyond the scope of Distillery or this document.

!!! tip
    I strongly recommend building releases you plan to deploy within a Docker
    container or Vagrant virtual machine. This allows you to tightly control the
    build environment for the release, and easily compile it for the target
    system's OS and architecture. Check out one of the guides for more information

## Hot upgrades and downgrades

## missing_chunk error

If you see the following error when upgrading:

    ERROR: release_handler:check_install_release failed: {'EXIT',
                                                          {{badmatch,
                                                           {error,beam_lib,
                                                            {missing_chunk,
                                                              ...}]

Then the version of the release that is currently installed had it's debug
information stripped (either via the `:strip_debug_info` setting, or manually
via `:beam_lib.strip`).

Distillery warns about this when you build an upgrade release, but since you
can build an initial release with this setting enabled before you start building
upgrades, Distillery cannot prevent this.

To fix this error, you will need to stop the currently running release, and extract
the release tarball over the top of the existing release root directory, then
start the release again.

### Unpack failed error

If you see the following error when upgrading:

    Unpack failed: {enoent,"/path/to/release/releases/0.2.0/myapp.rel"}

This is very likely due to repackaging the release tarball using the `tar` utility in a way
which changes the filename entries such that they do not match what the release handler is expecting.

The release tarball has entries of the form `releases/0.2.0/myapp.rel`, where GNU `tar` (and likely others)
may add entries relative to a directory, resulting in entries of the form `./releases/0.2.0/myapp.rel`. Despite
the fact that these equate to the same logical path, they are nevertheless considered different files in the tar
file format, as the name of the entry differs. Since the release handler is expecting the former, and cannot handle
the latter, your only option is to ensure entries are added to the tarball in the proper format.

!!! warning
    You should avoid repackaging the tarball generated by Distillery if at all
    possible. Distillery provides numerous forms of extensibility, namely
    plugins and overlays, which allow you to extend the contents of the release
    as needed. Distillery also provides boot hooks, which are shell scripts
    which allow you do just about anything you want at various lifecycle points
    in the boot process.

    If you need to modify the release on the target system, such as `vm.args`,
    consider using `REPLACE_OS_VARS` and environment variable references
    instead.

If you really need to repackage the release, you will need to use `:erl_tar`,
and match the way that Distillery builds it, so that the result matches both
what Distillery expects, and what the release handler expects.

## Permissions

Releases produced by Distillery must have the following requirements met in
terms of permissions, in order to run. As an example, we'll assume a release
which has been unpacked to `/opt/app`:

  * It must be able to read `$HOME/.erlang.cookie`
  * If `$HOME/.erlang.cookie` does not exist, it must be able to create it
  * It must be able to read/write to `RELEASE_MUTABLE_DIR`. By default, this
    would be `/opt/app/var` in our example.
  * It must be able read and write everything in `/opt/app`, unless:
    * `RELEASE_READ_ONLY` is set, in which case only read permissions are required
    * The release is _not_ an upgrade release, in which case only
      `RELEASE_MUTABLE_DIR` need be writable.
  * If `RELEASE_CONFIG_DIR` is set, the release must have read permissions to
    files in that directory. By default, this would be `/opt/app/` in our example.

!!! warning
    Use of `RELEASE_READ_ONLY` is intended for a specific use case. Namely,
    running release tasks as a user other than the user the release is being run
    as. You cannot start the release with this set, as a release expects to be
    able to modify files when run (in order to handle `REPLACE_OS_VARS`, amongst
    other things). The purpose of this environment variable is to prevent
    overwriting or changing permissions of files in the release accidentally as
    a side-effect of running unrelated tasks (such as `remote_console`).

Distillery will try to give you a friendly error, when it can, if permissions
are incorrect, but this may not always be the case. If you encounter a situation
where the errors are not friendly, please open an issue and we will try to improve them.
