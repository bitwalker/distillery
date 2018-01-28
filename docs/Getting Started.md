# Getting Started

## Understanding Releases

A release describes the set of applications it needs to run, and how to run them. The central artifact of
a release is a `.rel` file, which looks something like this:

```erlang
{release,{"test","0.1.0"},
         {erts,"8.2"},
         [{kernel,"5.1.1"},
          {stdlib,"3.2"},
          {poison,"3.1.0"},
          {logger,"1.4.1"},
          {compiler,"7.0.3"},
          {elixir,"1.4.1"},
          {test,"0.1.0"},
          {iex,"1.4.1"},
          {sasl,"3.0.2"}]}.
```

The second element of the release tuple is another tuple which describes the release name and version. The third element is a tuple which
describes the version of ERTS (the Erlang Runtime System) which the release is targeting. The final element is a list of the applications
and versions of those applications which are required to run the release.

This `.rel` file is used to generate a boot script (which has a `.script` extension) and a compiled form of it
(which has the `.boot` extension), which the Erlang Runtime System uses to boot the VM (very similar to how an OS is booted).
This boot script looks like so (it is heavily truncated here for our demonstration):

```erlang
%% script generated at {2017,2,22} {12,8,28}
{script,
    {"test","0.1.0"},
    [{preLoaded,
         [erl_prim_loader,erl_tracer,erlang,erts_code_purger,
          erts_dirty_process_code_checker,erts_internal,
          erts_literal_area_collector,init,otp_ring0,prim_eval,prim_file,
          prim_inet,prim_zip,zlib]},
     {progress,preloaded},
     {path,["$ROOT/lib/kernel-5.1.1/ebin","$ROOT/lib/stdlib-3.2/ebin"]},
     {primLoad,
         [error_handler,application,application_controller,application_master,
          code,code_server,erl_eval,erl_lint,erl_parse,error_logger,ets,file,
          filename,file_server,file_io_server,gen,gen_event,gen_server,heart,
          kernel,lists,proc_lib,supervisor]},
     {kernel_load_completed},
     {progress,kernel_load_completed},
     ..snip..
     {path,["$ROOT/lib/test-0.1.0/ebin"]},
     {primLoad,
         ['Elixir.Test,'Elixir.Test.Server', ...]},
     {kernelProcess,heart,{heart,start,[]}},
     {kernelProcess,error_logger,{error_logger,start_link,[]}},
     {kernelProcess,application_controller,
         {application_controller,start,
             [{application,kernel,
                  ..snip.. }]}},
     {progress,init_kernel_started},
     ..snip..
     {apply,
         {application,load,
             [{application,test,
                  [{description,"test"},
                   {vsn,"0.1.0"},
                   {id,[]},
                   {modules,
                       ['Elixir.Test','Elixir.Test.Server',
                        'Elixir.Test.ServerB','Elixir.Test.ServerC',
                        'Elixir.Test.Supervisor']},
                   {registered,[]},
                   {applications,[kernel,stdlib,poison,logger,elixir]},
                   {included_applications,[]},
                   {env,[]},
                   {maxT,infinity},
                   {maxP,infinity},
                   {mod,{'Elixir.Test',[]}}]}]}},
     ..snip..
     {progress,applications_loaded},
     {apply,{application,start_boot,[kernel,permanent]}},
     ..snip..
     {apply,{application,start_boot,[test,permanent]}},
     {apply,{c,erlangrc,[]}},
     {progress,started}]}.
```

As you can see, the boot script is full of low-level instructions which describe precisely how the VM, and the applications contained in the release, will be loaded and started. Every time you run `erl` or `mix` or `iex`, a boot script like the one above is used to boot the Erlang VM.

Given the description of a release (the `.rel`) and its boot script, a release is packaged by gathering all of the compiled `.beam` files required by the applications contained in the release, the target ERTS, and supporting files (`sys.config` for application configuration, `vm.args` for VM configuration, and a shell script used to set up the environment and run the release) - into a gzipped tarball for easy deployment.

## Releases and Hot Upgrades

The use of releases enables one of the Erlang VM's most powerful features - the ability to upgrade the system while it's running.
When generating upgrades, in addition to the `.rel`, `.script`, and `.boot` files, upgrades also require the definition of `.appup` files,
which describe how to upgrade from one version of an application to the next. Each application which has changed must have a `.appup` defined, or it will not be upgraded. This file is high-level and relatively easy to write. It is used to generate a `.relup` file, which is a low-level description of how the entire release will be upgraded (or downgraded) from one version to another; similar to how the `.script` corresponds to the `.rel` file.

While Distillery has the ability to generate `.appup` files automatically for you, you should always take the time to inspect them and
insure that they do the right thing for your application. It is also important that you understand how to leverage the
`system_code_change`/`code_change` callbacks in your processes to transform an old version of your state to the new version. If this is
not handled, your processes will be updated, but may fail in strange ways, due to missing struct fields you may have added in the new
version, etc.

## Installation/Setup

Simply add `distillery` to your dependencies, run `mix deps.get` and you are ready to start.

Within your project directory, you can then run `mix release.init` to setup your project with
a `rel` directory containing a release configuration file (`config.exs`). Take a look at the output
of `mix help release.init` to see how you can tweak this initial config file.

You can build a release with the `mix release` task. I strongly recommend reading the help output
of the task before using it.

## Configuration

The file you generated above, `rel/config.exs`, contains the configuration of any releases you may wish to define, like so:

```elixir
use Mix.Releases.Config,
  default_release: :foo,
  default_environment: Mix.env

environment :dev do
  set dev_mode: true 
  set include_erts: false
  set include_system_libs: false
  set cookie: :dev
end

environment :prod do
  set include_erts: true
  set include_system_libs: true
  set cookie: :prod
end

release :foo do
  set version: current_version(:foo)
end
```

Here we've defined two "environments", and one release. An environment is configuration specific to a particular target environment,
for some this might mean different configs for `test`, `staging`, and `prod`; for others, it might mean different architectures or devices. It
is flexible enough to support either, but out of the box it is set up to work with the current Mix environment, e.g. `MIX_ENV=prod` will use
the `:prod` environment defined above.

The release we defined above is expected to match up to an actual `:foo` application, which should be the current Mix project. If we were working
with an umbrella, or otherwise needed to deviate from this setup, we would define a release like so:

```elixir
release :myapp do
  set version: "0.1.0"
  set applications: [:app_a, :app_b, some_dep: :load]
end
```

The key differences from above being that we've explicitly set the version (as `current_version` works by detecting the version of the given application),
and explicitly set the applications to include in the release. As demonstrated above, you can also control the start type of an application in the release,
such as loading, but not starting an application you need to dynamically configure before use at runtime. The `applications` setting is used to override
any automatically determined information about a release, so in the case of the `:foo` release we originally defined, we could use the setting to override
the start type for one of its dependencies if we so desire.

## VM Configuration

Distillery will automatically generate a `vm.args` file for you, which configures the VM with a name and secure cookie, however there are times where
you may want to provide your own, but still take advantage of metadata provided by Distillery. In this case, you would put `set vm_args: "path/to/file"`
in your environment or release configuration, and define a file like the following at the path you provided:

```
## Node name
-name <%= release_name %>@127.0.0.1

## Node cookie, used for distribution
-setcookie ${NODE_COOKIE}
```

This file will be templated using the EEx template engine, and you can use any of the overlay variables described [here](https://hexdocs.pm/distillery/overlays.html).

Also shown above is the use of dynamic configuration. If `REPLACE_OS_VARS=true` is set in the runtime environment, a copy of `vm.args` will
be made with `${NODE_COOKIE}` replaced with the value of the `NODE_COOKIE` environment variable.

## Application Configuration

Distillery will compile the configuration you define in `config/config.exs` (or whatever your config_path is set to) into a `sys.config` file,
which is loaded by the VM at runtime to configure the applications in the release. A very important distinction to make here is
that `sys.config` is not a dynamic file like `config.exs`, this means that if your `config.exs` file has a call to say `System.get_env/1` in
it, that call will be evaluated at *compile-time*, not run-time. If you need such configuration, either use the `{:system, "ENV"}` config
options provided by your dependencies, and your application, or use dynamic configuration, as described above for `vm.args`. The dynamic
configuration case has an additional limitation in Mix config files, because they can only be used within strings, making them unusable for
configuration which requires integer values or other datastructures. In those situations, you have a couple of options:

- Use `vm.args` with `-<appname> <key> ${ENV_VAR}` to configure those settings
- Use [Conform](https://github.com/bitwalker/conform), or other configuration management libraries to help work around this limitation.

## Next Steps

For more detail on building a release for a project, please see the [Walkthrough](https://hexdocs.pm/distillery/walkthrough.html)
doc. There is more detailed information on more advanced topics such as upgrades in other documents hosted here as well.

Please take the time to review the output of `mix help release`, as well as other `release.*` tasks,
they cover more detail about usage at the command line, and what the various options mean.

Additionally, if you want to know what a certain configuration option does, you can find that information
on the [Configuration](https://hexdocs.pm/distillery/configuration.html) page.
