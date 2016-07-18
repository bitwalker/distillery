# Custom Commands

Custom commands are extensions to the boot script, and are used in the same
way you use `foreground` or `remote_console`, in other words, they have the
appearance of being part of the boot script. Like hooks, they have access to
the boot scripts helper functions and environment.

## Example Usage

Given a config like the following:


```elixir
use Mix.Releases.Config

environment :default do
  set commands: [
    echo: "rel/commands/echo"
  ]
end

release :myapp do
  set version: current_version(:myapp)
end
```

And the command script under `rel/commands/echo`:

```shell
echo "$2"
```

When you build your release, you can then call your command like so:

```
> rel/myapp/bin/myapp echo hi
hi
```

You have access to anything defined in the boot script's environment,
including it's helper methods. At this point in time there is not a public
API for these things, and no documentation on what is there, so if you need
something from there right now, you'll have to do some experimenting, however
I plan to define an API for these scripts, as well as document what env vars
you can use and what their values are.
