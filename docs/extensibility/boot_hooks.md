# Boot Hooks

Boot hooks are scripts which execute pre/post to events that occur in the run control script.

## Events

- `pre_configure`, occurs before `REPLACE_OS_VARS` triggers replacement, and before any generated files are generated
- `post_configure`, ocurrs after environment variable replacement and after generated files are generated
- `pre_start`, occurs before the release is started
- `post_start`, occurs right after the release is started
- `pre_stop`, occurs after a request to stop the release is issued, but before the release is stopped
- `post_stop`, occurs after the release is stopped
- `pre_upgrade`, occurs before the release is upgraded
- `post_upgrade`, occurs right after the release is upgraded

## Example Usage

Given a config like the following:


```elixir
use Distillery.Releases.Config

environment :default do
  set pre_start_hooks: "rel/hooks/pre_start"
  set post_start_hooks: "rel/hooks/post_start"
end

release :myapp do
  set version: current_version(:myapp)
end
```

And the two hook scripts:

```shell
# rel/hooks/pre_start/echo.sh
echo "we're starting!"
```

```shell
# rel/hooks/post_start/echo.sh
echo "we've started!"
```

When you build your release, and run it, you'll see something
like the following:


```
> _build/dev/rel/myapp/bin/myapp foreground
we're starting!
...snip...
we've started!
...snip...
```

You have access to anything defined in the run control script environment, see [Shell Scripts](shell_scripts.md) for details.
