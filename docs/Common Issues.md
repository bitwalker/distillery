# Common Issues/Questions

## What should I put in my .gitignore?

As of today in master, you do not need to .gitignore anything. Previously,
you needed to put `rel/<release_name>` in your .gitignore if you didn't
want to source control artifacts. Release artifacts are now produced under
`_build/$MIX_ENV/rel/<release_name>`.

You *do* need to make sure that you are source controlling everything needed
to construct a release if you are doing CI, for example, Phoenix produces a 
default .gitignore which contains `priv/static`, but you need those assets when
building your release, so you'll need to make sure that these are *not* ignored.

## I have two dependencies with conflicting modules

This is a tough situation to fix, and is a key reason why the community has a convention
of namespacing modules. However if you encounter this situation in your own projects, the
first step is to fork one (or both) projects, namespace the problem modules, and then
use your fork until the author of the project merges your changes.

It is critical that we as a community let maintainers know when they have modules which
conflict with other projects, and encourage each other to namespace our projects properly
to prevent this from happening.

## Why do I have to set both MIX_ENV and --env?

Mix environments and release environments represent two distinct concepts, though they appear to be the same.

Mix environment is used during compilation to determine what dependencies to fetch/build, can be used to compile
modules differently based on environment, and to determine what configuration to use. In some cases this aligns
perfectly with your deployment environments, but not always. For example, you may build with `MIX_ENV=prod` for
both production and staging environments, but want different release configurations for each of them.

Release environments correspond to the environments in which you deploy releases. Your dev environment for releases
might only be used on your local machine for quick iteration, you may want to define both staging and production
environments, or perhaps more.

However, if your build and deployment environments correspond, there is a way to simplify your life a bit by configuring
Distillery to use `MIX_ENV` as the release environment:

```elixir
use Mix.Releases.Config,
  default_environment: Mix.env
```

You must ensure that you have environments defined in `rel/config.exs` for each of your build environments where you
will run `mix release`, but with this configuration you can simply run `MIX_ENV=whatever mix release` and the correct
release configuration will be selected.

## Starting multiple instances on a single machine fails

If you encounter the following error:

```
> bin/myapp console
{error_logger,{{2016,8,26},{23,11,6}},"Protocol: ~tp: the name myapp@127.0.0.1 seems to be in use by another Erlang node",["inet_tcp"]}
...snip..
```

The issue here is that you are attempting to start two instances of the Erlang VM with the same
fully-qualified node name. You must modify the release's `vm.args` file and change the `-name` argument
to something unique.

This can also happen if for some reason the last instance you started is hung while stopping,
and you try to start a fresh instance. In this case you can just `kill <pid>` to stop the old node.

## Natively-implemented Functions (NIFs)

If you forget to compile NIFs on the same OS/architecture as your target system, your release
will fail at runtime when it attempts to load them. You must cross-compile your release in that case,
or ensure that your build environment and target environment share the same OS/architecture, and system
packages.

Cross-compiling a release with `include_erts: <path>` *only* cross-compiles the BEAMs, it does not
cross-compile any natively-implemented dependencies, such as those contained in `comeonin` and other packages.

If you must cross-compile, you will need to make sure that you set up the cross-compilation toolchain for
those dependencies as well, which is beyond the scope of Distillery or this document.

In the future I will try to provide a walkthrough on how to set this up, but it's important to note
that each dependency may be different, and no guide can cover all of the requirements for a specific
package. It is up to the package maintainers to provide instructions on how to cross-compile NIFs.

## Upgrade failures

If you see the following error when upgrading:

```
ERROR: release_handler:check_install_release failed: {'EXIT',
                                                      {{badmatch,
                                                        {error,beam_lib,
                                                         {missing_chunk,
                                                          ...}]
```

Then the currently installed version had its debug information stripped via
`strip_debug_info: true` in the release configuration. Distillery will print a
warning when you build an upgrade with that setting set to `true`, because this
is what happens when you try to upgrade a release which has had its BEAMs
stripped. To fix this, you will need to stop the currently running release and
extract the tarball over the top of the release root directory, then start the
release again. To prevent this from happening in the future, set
`strip_debug_info: false` when using hot upgrades.
