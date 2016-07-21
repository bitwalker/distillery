# Upgrades and Downgrades

## A word of caution

In general, unless you have a strong reason for using hot upgrades, it's almost always simpler to just
do rolling releases. Hot upgrades are an amazing capability, but they are deceptively simple to use due
to the automatic appups. If you get to the point where you need to write your own appups, you will need
to become intimately familiar with them, and there is a lot of complexity hidden there. However, there
is nothing preventing you from using upgrades until you hit that point, doing a rolling release, then
continuing with upgrades from there - it ultimately depends on your needs. I would caution anyone thinking
of using them to evaluate whether they are truly necessary for their use case.

## A bit about upgrades

When building upgrade releases, Distillery will ensure that all modified
applications have appups generated for them. Appups are what tell `:systools` how
to generate the `relup` file, which are low-level instructions for the release handler,
which tell it how to load/remove/change modules in the system during a hot upgrade.

Without an appup, an upgrade cannot succeed, because the release handler will not know
how to upgrade that application. Distillery is very intelligent about ordering instructions
based on additions/deletions/changes to modules, based on whether they are special processes
(`gen_server`, `supervisor`, `proc_lib`-started apps), and their dependencies to each other.
However, while Distillery's appup generator is quite good, it can't be perfect for all applications,
or all situations. There will be times when you need to modify these appups, or provide your own.
For instance, you may need to upgrade state of a `gen_server` between one version and another based
on some external state. Appups provide facilities for passing extra data to the code change handler
for these situations. Distillery cannot know what data to provide, or when it's needed, and that's when
you'll need to step in.

## Appups

**NOTE**: This is a copy of my wiki article on appups in the `relx` repository.

Ok, so you've generated a release, deployed it to your target system, made some code changes in development,
and now you want to generate a release package that will allow you to do a hot upgrade. In order to do this,
you must create a project.appup file, which will go in the ebin directory of your production build.

There is no real clear example of how appups are supposed to be built, so the following example is intended
to help you get started. For more complicated application upgrades, you'll want to check out the
[Appup Cookbook](http://erlang.org/doc/design_principles/appup_cookbook.html).

Given a sample application called `test`, with a supervisor (`test_sup`), and a `gen_server` (`test_server`),
you should have a `test.app` file in `_build/<env>/lib/test/ebin` that looks something like the following:

```erlang
{application,test,
             [{registered,[]},
              {description,"test app"},
              {mod,{test,[]}},
              {applications,[stdlib,kernel]},
              {vsn,"0.0.1"},
              {modules,[test,test_server,
                        test_sup]}]}.
```

If you make code changes to, `test_server` for instance, the following is a simple appup file that will
load your project's application, and call `code_change/3` on both `test_sup` and `test_server`. The first
`"0.0.1"` block is the order of operations for the upgrade, the second one is the order of operations for the
downgrade (note that it's in reverse order of the upgrade process).

```erlang
{"0.0.2",
 [{"0.0.1",
   [{load_module,test},
    {update,test_server,infinity,
            {advanced,[]},
            brutal_purge,brutal_purge,[]},
    {update,test_sup,supervisor}]}],
 [{"0.0.1",
   [{update,test_sup,supervisor},
    {update,test_server,infinity,
            {advanced,[]},
            brutal_purge,brutal_purge,[]},
    {load_module,test}]}]}.
```

This is the simplest case for an appup, but it should cover you for common upgrade scenarios. For anything more complicated,
I encourage you to read the Appup Cookbook, to fully understand each of the options for the upgrade process.
Note that the `{advanced, []}` tuple in each of the blocks is where you would pass additional arguments to `code_change`, if needed.

To generate an upgrade release, you'll need to pass `--upgrade` to `mix release`. To generate an upgrade from an arbitrary
version you've previously built, pass `--upfrom=<version>`. Distillery will look for the appup in the ebin of your current build.
