# Command Line Interface

## Mix Tasks

Distillery's command line is exposed via three Mix tasks, `release`, `release.clean`, and `release.init`.
Your best bet is to simply run `mix help release` to see the help for a specific task, but a few notes
are here which are likely of interest to most of you:

### Executables

Distillery has the capability to generate executable releases via the `--executable` flag. 
These are self-extracting tar archives with a header script which passes arguments to the boot script upon extraction. 
It will only extract itself on the first run, to `./tmp/<rel_name>`, further runs will use the already extracted release for efficiency.
If you want the executable to remove the extracted files after the release terminates, you can enable this auto-cleanup by marking
the executable as transient with `--transient`.

**NOTE**: The executable feature is restricted to non-Windows platforms.

This feature is ideal for building command-line applications. The reason why you might want to use this approach versus escripts is that
you are able to bundle the Erlang runtime with the executable, and thus deploy the app to target systems which do not have Erlang/Elixir installed,
additionally, you have the flexibility to use these applications as daemons with all of the tooling associated with releases (e.g. remote shell).

### Warnings as Errors

If you are using Distillery as part of your CI pipeline, you probably want the release to fail fast if
warnings are detected. You can do this by passing `--warnings-as-errors` to `mix release`.

### Missing Applications

Distillery will produce a warning if it detects that there are runtime dependencies, either direct or
transitive, which are not in the application tree (i.e in `applications` or `included_applications`
of your `mix.exs`, or any of the apps in those lists). It is not technically a fatal error, so the release
will proceed as normal, but it's important that you take action on this warning. Your options are as follows:

- You hate this warning, you never want to see it: pass `--no-warn-missing`, or..
- You know that a given application doesn't need to be present:

```elixir
config :distillery,
  no_warn_missing: [
    :ignore_this_app,
  ]
```

## Release Commands

The easiest way to see what commands there are is to run `bin/myapp` without any arguments, this will dump help
information about what commands are available, and how to use them.
