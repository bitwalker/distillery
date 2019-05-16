# Release Configuration

Looking for how to handle configuration of your app when using releases?
Check out [Runtime Configuration](runtime.md).

Below is a brief overview of the release configuration file format:

```elixir
use Distillery.Releases.Config,
    # This sets the default release built by `mix distillery.release`
    default_release: :default,
    # This sets the default environment used by `mix distillery.release`
    default_environment: :dev

# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile
environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :test
end
environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :crypto.hash(:sha256, System.get_env("COOKIE")) |> Base.encode16 |> String.to_atom
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix distillery.release`, the first release in the file
# will be used by default
release :myapp do
  set version: current_version(:myapp)
end

# You can release umbrella apps individually, using the above format,
# or as a single release, using the following form, where you give
# the umbrella release a name, a version, and then add the umbrella
# applications you want to include in the release.
release :myumbrella do
  set version: "1.0.0"
  set applications: [
    :umbrella_app1,
    :umbrella_app2
  ]
end
```

Please see the module docs for `Distillery.Releases.Config` for specifics on the
`environment/2`, `release/2`, `set/1`, and other macros.

## Release settings

The following is a list of config options specific to releases


  * `version (string)` (required) The version of this release.
  Use `current_version/1` to load the current version
  of an application instead of hardcoding it.
  * `applications ([atom | atom: start_type])` (optional) - A list of
  applications which should be included in the release. By default, the
  list will contain required apps, and apps discovered by walking the tree
  of dependencies. In umbrella apps, you must provide this setting, as it
  is not possible to know which applications should be included. You can
  also specify the start type of an application by providing the application
  and start type as a tuple. Valid start types are `:load`, `:permanent`,
  `:temporary` and `:transient`.  See [this doc](http://erlang.org/doc/design_principles/applications.html),
  section 7.9, for more information.

!!! warning
    Using a start type of `:load` is dangerous, as it can result in a release which
    cannot completely boot up, but which never raises an error. Distillery will warn you
    if you use a start type of `:load` in a situation where it should be allowed to start
    normally (due to being declared as a dependency of another app, which is not an included
    application). You must add applications with a start type of `:load` to `:included_applications`
    in `mix.exs`, as well as any applications which depend on that application being started. If
    you do not, it is very likely your release will only partially boot, as a deadlock cycle is formed
    between your application, the "load-only" applications, and dependencies which depend on those "load-only"
    applications being started.

## Environment/Release settings

The following is a full list of config options for both releases
and environments.


  * `output_dir (string)` - the path where the release artifacts will be
  generated.  by default this is under `_build/<$MIX_ENV>/rel/<release_name>`

  * `dev_mode (boolean)` - symlink compiled files into the release, rather than
  copy them.  This allows you to recompile and the release will be automatically
  updated. **NOTE:** Use only for development.

  * `vm_args (string)` - a path to a custom vm.args file

  * `config_providers ([module | {module, [term]}])` - a list of runtime configuration
  providers to use

  * `config (string)` - a path to a custom config.exs file, this will be used when
  generating the `sys.config` for the release

  * `sys_config (string)` - a path to a custom `sys.config` file, this will be used in
  place of generating a `sys.config`, and thus will result in the config setting being
  ignored, choose one or the other as needed

  * `include_erts (boolean | string)` - whether to include the system ERTS or not, a path
  to an alternative ERTS can also be provided

  * `include_src (boolean)` - should source code be included in the release

  * `included_configs ([string])` - Erlang allows `sys.config` to include other
  `.config` files. Distillery supports this feature via `included_configs`. This
  option expects a list of paths to include, where each path will be read at runtime
  when the release boots and the configuration settings it contains will take precedence
  over the configs that came before it. All such includes will have precedence over the
  default configuration generated with the release.  **NOTE:** It is recommended to use absolute paths.

  * `strip_debug_info (boolean)` - should debugging info be stripped from BEAM files in the release
  **CAUTION:** This setting will result in releases which cannot be hot upgraded. Only use this if you need it.

  * `erl_opts (string)` - a string of Erlang VM options to be passed along to `erl`

  * `run_erl_env (string)` - a string of environment variables to be applied to `run_erl`

  * `commands [atom: string]` - Commands are extensions to the release run control script
  which will run like any other command, i.e. `foreground`, and are implemented as shell
  scripts, which will be copied into the release when it is built, just like hooks.

  * `overrides ([atom: string])` - During development its often the case that you want to
  substitute the app that you are working on for a 'production' version of an app. You can
  explicitly tell Mix to override all versions of an app that you specify with an app in an
  arbitrary directory. Mix will then symlink that app into the release in place of the specified
  app. Be aware though that Mix will check your app for consistency so it should be a normal OTP
  app and already be built.

  * `overlay_vars (Keyword.t)` A keyword list of bindings to use in overlays

  * `overlays ([Overlay.t])` - A list of overlay operations to perform against the release,
  prior to archival, such as copying files, symlinking files, etc.
      * `{:copy, from_path, to_path}` - copy a file
      * `{:link, from_path, to_path}`- symlink a file
      * `{:mkdir, path}` - ensure a path exists
      * `{:template, template_path, output_path}` - generate a file from a template

  * `pre_configure_hooks (string)` - A path to a directory containing shell scripts which will
  be executed before configuring a release

  * `post_configure_hooks (path)` - A path to a directory containing shell scripts which will
  be executed after configuring a release

  * `pre_start_hooks (path)` - A path to a directory containing shell scripts which will
  be executed prior to starting a release

  * `post_start_hooks (path)` - A path to a directory containing shell scripts which will
  be executed after starting a release

  * `pre_stop_hooks (path)` - A path to a directory containing shell scripts which will
  be executed prior to stopping a release

  * `post_stop_hooks (path)` - A path to a directory containing shell scripts which will
  be executed after stopping a release

  * `pre_upgrade_hooks (path)` - A path to a directory containing shell scripts which will
  be executed before performing a release upgrade

  * `post_upgrade_hooks (path)` - A path to a directory containing shell scripts which will
  be executed after performing a release upgrade
