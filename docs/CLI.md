# Command Line Interface

Distillery's command line is exposed via three Mix tasks, `release`, `release.clean`, and `release.init`.
Your best bet is to simply run `mix help release` to see the help for a specific task, but a few notes
are here which are likely of interest to most of you:

## Warnings as Errors

If you are using Distillery as part of your CI pipeline, you probably want the release to fail fast if
warnings are detected. You can do this by passing `--warnings-as-errors` to `mix release`.

## Missing Applications

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
