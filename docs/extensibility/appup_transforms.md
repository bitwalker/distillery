# Appup transforms

There are times where you want to automate some change to one or more appups
programmatically, such as changing the way processes running old code are purged
(brutal or soft), running a function after a particular application is upgraded,
and more.

Distillery provides appup transforms for this purpose. A transform is a module
which exports two callbacks, `up` and `down`. These callbacks are invoked when
transforming the instruction set for a specific application when upgrading and
downgrading respectively. This transformation happens when building a release.

Both `up` and `down` receive the set of instructions to transform, the application
those instructions apply to, the source version, the target version, and the
options given to the transform.

## Configuration

You can add a transform to a release as shown below:

```elixir
release :myapp do
  set appup_transforms: [
    {Distillery.Test.SoftPurgeTransform, [default: :brutal_purge, overrides: [test: :soft_purge]]}
  ]
end
```

The transform module shown above is designed to transform the purge mode for all
instructions. It uses the `default` option to specify the purge mode to use for
all instructions, and uses the `overrides` option to allow changing the purge
mode for specific applications.

## Implementation

!!! tip
    If you want to see the implementation of the transform shown above, it can
    be found in `test/support/purge_transform.ex` [here](https://github.com/bitwalker/distillery)
    
The implementation of a basic transform looks like so:

```elixir
defmodule MyApp.MyTransform do
  use Distillery.Releases.Appup.Transform
  
  def up(app, _v1, _v2, instructions, opts) do
    # Transform upgrade instructions
  end

  def down(app, _v1, _v2, instructions, opts) do
    # Transform downgrade instructions
  end
end
```

!!! warning
    You must ensure that you reverse any actions you perform in either
    direction; in other words, if you change something during an upgrade, you
    must undo that change in the downgrade instructions.
    
!!! warning
    In addition to the warning above, your appups should only execute instructions
    which apply to the Erlang/Elixir code itself - do not execute changes to the
    system environment, run database migrations, or otherwise modify things
    outside the OTP system. The reason for this is simple: the guarantees
    provided by OTP's hot upgrades are only held when restricted to OTP itself, 
    no guarantees can be made about rolling back actions which interact with
    external systems, as they may partially succeed and then fail, at which
    point OTP will roll back the upgrade, but the mutations to the external
    system will remain, which may make break the old version of the code, and
    make a new version more difficult to apply.

Distillery does not provide any transforms out of the box, but some may be found
in the Edeliver project.
