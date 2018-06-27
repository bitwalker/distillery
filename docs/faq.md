# FAQ

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

## What is the difference between Mix environments and Distillery environments?

Mix environments and release environments represent two distinct concepts, though they appear to be the same.

Mix environment is used during compilation to determine what dependencies to fetch/build, can be used to compile
modules differently based on environment, and to determine what configuration to use. In some cases this aligns
perfectly with your deployment environments, but not always. For example, you may build with `MIX_ENV=prod` for
both production and staging environments, but want different release configurations for each of them.

Release environments correspond to the environments in which you deploy releases. Your dev environment for releases
might only be used on your local machine for quick iteration, you may want to define both staging and production
environments, or perhaps more.

However, if your build and deployment environments correspond, by default Distillery will look for an environment
definition which matches the value of `MIX_ENV`.

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

I strongly recommend building releases you plan to deploy within a Docker container or Vagrant virtual machine.
This allows you to tightly control the build environment for the release, and easily compile it for the target
system's OS and architecture. In the near future I will try to provide a walkthrough on how to set this up.

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

---

If you see the following error when upgrading:

```
Unpack failed: {enoent,"/path/to/release/releases/0.2.0/myapp.rel"}
```

This is very likely due to repackaging the release tarball using the `tar` utility in a way
which changes the filename entries such that they do not match what the release handler is expecting.

The release tarball has entries of the form `releases/0.2.0/myapp.rel`, where GNU `tar` (and likely others)
may add entries relative to a directory, resulting in entries of the form `./releases/0.2.0/myapp.rel`. Despite
the fact that these equate to the same logical path, they are nevertheless considered different files in the tar
file format, as the name of the entry differs. Since the release handler is expecting the former, and cannot handle
the latter, your only option is to ensure entries are added to the tarball in the proper format.

However, I would strongly suggest you reevaluate any process which has you repackaging the tarball. Distillery in
particular is designed with a plugin system and overlay system so that you can extend the contents of the tarball as
needed by hooking into those. If you need to modify things on the target system, such as `vm.args`, considering using
features like `REPLACE_OS_VARS=true` so that you can base information in the configuration or `vm.args` on data exported
in the system environment; if that isn't an option, you can use shell hooks (e.g. `pre_upgrade` to copy files where they need to
go). If you _really_ need to repackage the release tarball, you can do this, but you may have an easier time of it if you 
can repackage it with `erl_tar`, which will match the way Distillery builds it, and the release handler unpacks it.


## Permissions

One of the things that often catches people off guard are the permissions required by a release, particularly with upgrades.

### Without upgrades

The following is a list of things the release handler expects:

- It can read/write to `$HOME/.erlang.cookie` and create it if it doesn't exist
- It can read/write to `$RELEASE_MUTABLE_DIR` if set, otherwise it needs to read/write to `/var` directory under the directory it's deployed to
- It can read the directory it's deployed to

### With hot upgrades

- It can read/write to `$HOME/.erlang.cookie` and create it if it doesn't exist
- It can read/write to `$RELEASE_MUTABLE_DIR` if set, otherwise it needs to read/write to `/var` directory under the directory it's deployed to
- It can read/write the directory it's deployed to

If permissions are wrong, you may see a variety of errors depending on what permissions are off, but ensure the list above is satisfied, and you should be in good shape.
