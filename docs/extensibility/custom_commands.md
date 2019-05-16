# Custom Commands

Custom commands are extensions to the management script, and are used in the same
way you use `foreground` or `remote_console`, in other words, they have the
appearance of being part of the release command line interface. Like hooks, they have access to
the management scripts helper functions and environment.

## Example Usage

Given a config like the following:


```elixir
use Distillery.Releases.Config

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

## Mix Tasks

Since Mix Tasks have not been supported in releases, it can feel frustrating to have to write two
interfaces for one task. Distillery now provides tools to make this no longer an issue:

First, you should define your Mix task as you would normally. The entry point for your task will
then be something like `Mix.Tasks.MyTask.run/1`.

!!! warning
    You can reuse Mix tasks this way, but you must avoid the use of Mix APIs, as they depend on Mix being
    started, as well as having the project context available, which is not the case in releases.

Now add a custom command to your release like so:

```elixir
release :myapp do
  set commands: [
    my_task: "rel/commands/my_task"
  ]
end
```

And here's how you invoke your Mix task from the release (in `rel/commands/my_task`):

```shell
#!/usr/bin/env bash

release_ctl eval --mfa "Mix.Tasks.MyTask.run/1" --argv -- "$@"
```

Now, when you run `bin/myapp my_task foo bar`, your Mix task will be invoked like so:

```elixir
Mix.Tasks.MyTask.run(["foo", "bar"])
```

That's all there is to it!

!!! warning
    You should use `release_remote_ctl rpc` rather than `release_ctl eval` though,
    if your task needs to execute in the context of the running release.

You have access to anything defined in the management scripts environment, see
[Shell Scripts](shell_scripts.md) for details.
