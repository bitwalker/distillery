# Boot Hooks

Boot hooks are scripts which execute pre/post to events that occur in the boot script.
Currently, that is `pre/post_start`, and `pre/post_stop`. These scripts are simply
shell scripts which will be sourced into the boot script during execution.

## Example Usage

Given a config like the following:


```elixir
use Mix.Releases.Config

environment :default do
  set pre_start: "rel/hooks/pre_start"
  set post_start: "rel/hooks/post_start"
end

release :myapp do
  set version: current_version(:myapp)
end
```

And the two hook scripts under `rel/hooks`:

```shell
# pre_start
echo "we're starting!"
```

```shell
# post_start
echo "we've started!"
```

When you build your release, and run it, you'll see something
like the following:


```
> rel/myapp/bin/myapp foreground
we're starting!
...snip...
we've started!
...snip...
```

You have access to anything defined in the boot script's environment,
including it's helper methods. At this point in time there is not a public
API for these things, and no documentation on what is there, so if you need
something from there right now, you'll have to do some experimenting, however
I plan to define an API for the hook scripts (and custom command scripts), as
well as document what env vars you can use and what their values are.
