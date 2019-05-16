# Appups

To learn more about the contents of `.appup` files, specifically the instructions you can use within
them, please review the [appup manual](http://erlang.org/doc/man/appup.html) first, and consider this
page more of an overview.

## Overview

In a nutshell, appups are a description of how to upgrade and downgrade a given application from one version to
another. It contains the name of the application, and two sets of instructions, one which will upgrade the application
to the newer version, and one which will downgrade the application to the original version. The set of instructions,
and the format of the file, are described in the [appup manual](http://erlang.org/doc/man/appup.html).

So you've generated a release, deployed it to your target system, and now made some code changes in development.
You want to hot upgrade your application rather than restarting it to deploy the upgrade, so you need to generate 
a release package that will allow you to do a hot upgrade. In order to do this, you must create a `myapp.appup` file, 
which will go in the `_build/<env>/lib/<myapp>/ebin` directory, where `<env>` is the Mix environment (i.e. value of `Mix.env`) 
your release will be generated from.

By default, Distillery will attempt to generate an appup for you, but there is no foolproof way to automatically generate appups for 
an application, and even though there are some general guidelines, which is what Distillery uses to generate appups for you, you will
still want to review these to make sure the application will be upgraded the way you expect.

!!! tip
    You can see the appup Distillery will use via `distillery.gen.appup`. This
    generates the appup under `rel`, and allows you to modify it and source
    control it.

!!! tip
    You can programmatically apply changes to appups with [Appup Transforms](../extensibility/appup_transforms.md)

## Reviewing generated appups

How do you know if the generated appups look right though? There are a few tips you can follow:

  * Did you change the internal state of any special processes? (i.e. `Gen*` processes). If so, the process needs
    to handle the `code_change` or `system_code_change` callbacks to make sure the state is converted during the upgrade.
    This isn't in the appup, but it is required, and if you need any additional arguments to the code change handler, then
    you will want the `:update` instruction corresponding to that module to provide those arguments via the `{:advanced, args}` tuple.
  * Did all of the modules you change result in either `:update` or `:load_module` instructions?
  * Did all of the modules you add result in `:add_module` instructions? Likewise with `:remove_module` for any deleted modules.
  * Did all of the modules you rename result in `:remove_module` and `:add_module` instructions corresponding the old and new names?
  * If you need to execute any custom steps during the upgrade, you will need to use either code change handlers, or a custom `:apply` instruction
  * If your upgrade is also upgrading the version of ERTS (Erlang Runtime System) used, there should be a `:restart_new_emulator` instruction
  * If your upgrade needs to restart the emulator for any reason, there should be a `:restart_emulator` instruction

## Designing appups

There are no hard and fast rules when it comes to writing your own appups,
beyond the tips provided in the last section, and so examples are difficult to
provide. There are some useful guides available however, both the appup manual
mentioned previously, as well as the [Appup Cookbook](http://erlang.org/doc/design_principles/appup_cookbook.html)
provide a wealth of information on how to construct appups.

That said, let's look at a trivial example of an upgrade. Given a sample
application called `test`, with a supervisor (`Test.Supervisor`), and a
`GenServer` (`Test.Server`), you should have a `test.app` file in
`_build/<env>/lib/test/ebin` that looks something like the following after
compiling the version, `0.2.0`, which we're upgrading to from `0.1.0`:

```erlang
{application,test,
             [{applications,[kernel,stdlib,elixir,logger,distillery]},
              {description,"test"},
              {modules,['Elixir.Test','Elixir.Test.Server',
                        'Elixir.Test.Supervisor']},
              {registered,[]},
              {vsn,"0.2.0"},
              {mod,{'Elixir.Test',[]}},
              {extra_applications,[logger]}]}.
```

Assuming we've modified `Test.Server`, the following is the automatically
generated upgrade Distillery provides for the release:

```
{"0.2.0",
 [{"0.1.0",[{update,'Elixir.Test.Server',{advanced,[]},[]}]}],
 [{"0.1.0",[{update,'Elixir.Test.Server',{advanced,[]},[]}]}]}.
```

This appup simply ensures that `Test.Server` is suspended, the `code_change`
handler is called, and then the process is resumed once the new version of the
code has been loaded, using the new state the `code_change` handler returned. It
is not clear that those are the steps which occur, but that is the purpose of
the appup manual, which describes what each instruction does. You can also
review the `relup` file under `_build/<env>/rel/<myapp>/releases/<latest_ver>/`
once the release has been built, which contains all of the low-level
instructions that the appup compiled to for a more detailed view of what will
happen.

Another item of note in the above example, is that the `:update` instruction
contains a `{:advanced, args}` tuple, which tells the release handler to give
`args` to the `code_change` callback as its extra argument. You can use this to
provide additional context to the `code_change` handler if needed. By default,
Distillery will set this to an empty list.

It is important that you order the instructions such that processes which depend
on each other are upgraded in an order compatible with the dependencies between
them. If you have `proc_a` and `proc_b`, and `proc_a` calls `proc_b` for
something, upgrade `proc_b` first, then `proc_a`. When processes are upgraded,
they are suspended during the upgrade, but in-flight requests will be handled by
the old version, until the upgrade is complete and the new version is
un-suspended. Distillery automatically performs a topological sort when it
generates appups, but if you are writing your appup by hand, you will need to do
this on your own. Perhaps in a future change, I can integrate things such that
Distillery checks your work, but that is not the case today.

The above example is the simplest case for an appup, but hopefully gives you a
feel for how you can build up to larger and more complex appups. You should
always keep the appup manual, and the Appup Cookbook at hand for reference when
writing your own, as you will want to check your work to make sure the
instructions you are defining will result in the correct upgrade or downgrade
behaviour.

## Generating appups

To generate appups for modification and source control, you can use the
`distillery.gen.appup` task. See the `help` output from the task for more
information about its usage.

In short, it will produce appup files under `rel`, which can then be edited and
added to source control so that they are present for release builds. When a
release is built, appups found there will be used in place of auto-generating
appups during the release build.
