# Boot Hooks

Boot hooks are scripts which execute pre/post to events that occur in the boot script.
Currently, that is `pre/post_start`, and `pre/post_stop`. These scripts are simply
shell scripts which will be sourced into the boot script during execution.

## Example Usage

Given a config like the following:


```elixir
use Mix.Releases.Config

environment :default do
  set pre_start_hook: "rel/hooks/pre_start"
  set post_start_hook: "rel/hooks/post_start"
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
see [Shell Script API](https://hexdocs.pm/distillery/shell-script-api.html) for
details.
