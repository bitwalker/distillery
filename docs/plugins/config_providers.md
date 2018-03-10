# Custom Configuration Providers

Distillery now provides the capability to natively support `config.exs` files, also known as `Mix.Config`,
as well as custom configuration providers of your own design.

## Implementing A Provider

To implement one, you simply need to implement the callbacks for the provider behaviour, as shown in the
example below:

```elixir
defmodule SystemEnvProvider do
  use Mix.Releases.Config.Provider

  def init(_args), do: :ok

  def get(keypath) do
    keypath
    |> Enum.map(&Atom.to_string/1)
    |> Enum.map(&String.upcase/1)
    |> Enum.join("_")
    |> System.get_env
  end
end
```

See the module docs for `Mix.Releases.Config.Provider` if you want to know more about the behaviour of these callbacks.

In our example above, this provider does nothing during `init`, but when asked to look up the value for the given
key path (which is simply a list of atoms where the first atom is the application name), it converts the key path
into a well-known structure for environment variables and tries to pull it out of the environment. Given the key
path `[:myapp, :foo]`, it would look for `MYAPP_FOO` in the system environment.

## Notes

Currently, `get/1` is not used by anything directly, but you can use it yourself to ask for a configured value,
simply by calling `Mix.Releases.Config.Provider.get/1`. This will try all of the config providers until one returns
a non-nil value, or nil if no value was found. I am considering some features which may take advantage of this API
in the future, but currently it is just a placeholder.

The `init/1` function is called during startup, before any applications are started, with the exception of core
applications required for things to work, namely `:kernel`, `:stdlib`, `:compiler`, and `:elixir`. Everything is
loaded in a release, but you may still want to be explicit about loading applications just in case the provider
ends up running in a relaxed code loading environment.
