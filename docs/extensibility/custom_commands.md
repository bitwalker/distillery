# Custom Commands

Custom commands are extensions to the management script, and are used in the same
way you use `foreground` or `remote_console`, in other words, they have the
appearance of being part of the release command line interface. Like hooks, they have access to
the management scripts helper functions and environment.

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
echo "$1"
```

When you build your release, you can then call your command like so:

```
> _build/dev/rel/myapp/bin/myapp echo hi
hi
```

You have access to anything defined in the management scripts environment, see
[Shell Script API](https://hexdocs.pm/distillery/shell-script-api.html) for details.
