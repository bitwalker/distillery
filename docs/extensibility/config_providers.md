# Custom Configuration Providers

Distillery now provides the capability to implement custom configuration
providers for loading and persisting runtime configuration during boot. These
providers are able to replace the use of `sys.config` and `config.exs` if
desired.

## Implementing a Provider

To implement a new configuration provider, a module must implement the
`Distillery.Releases.Config.Provider` behavior, which has a single callback, `init/1`.

Config providers are executed in a pre-boot phase, in their own instance of the
VM, where all applications are loaded, and only kernel, stdlib, compiler, and
elixir are started. Providers may start any application needed to do config provisioning,
e.g. inets/crypto/ssl, as long as the application is part of the release.
Providers are expected to push configuration into the application environment
(e.g. using `Application.put_env/3`). Once all providers have run, the
application environment will be dumped to a final sys.config file, which is
subsequently used when booting the "real" release.

!!! warning
    Since config providers only execute pre-boot, you must restart the release to
    pick up configuration changes. If using hot upgrades, the config providers
    will run during the upgrade, and so will pick up any config changes at that time.

There are some important properties you must keep in mind when designing and
implementing a provider:

- You have access to the code of all applications in the release, _but_, only
  `:kernel`, `:stdlib`, `:compiler`, and `:elixir` are started when the
  provider's `init` callback is invoked.
- If you must start an application in order to accomplish some goal, at present,
  you must manually start them with `Application.start/2` or
  `Application.ensure_all_started/1`
- If you need to start an application to run the provider, and the application
  needs configuration, you have a circular dependency problem. In order to solve
  this, you need to have users provide the initial configuration via
  `sys.config` or `config.exs`, that way you can bootstrap the provider.
  
## Example: JSON

The following is a relatively simple example, which allows one to represent the
typical `config.exs` structure in JSON, so given the following Mix config file:

```elixir
use Mix.Config

config :myapp,
  port: 8080

config :myapp, :settings,
  foo: "bar"
```

The JSON representation expected by this provider would be:

```json
{
  "myapp": {
    "port": 8080,
    "settings": {
      "foo": "bar"
    }
  }
}
```

The actual implementation looks like this:

```elixir
defmodule JsonConfigProvider do
  use Distillery.Releases.Config.Provider

  def init([config_path]) do
    # Helper which expands paths to absolute form
    # and expands env vars in the path of the form `${VAR}`
    # to their value in the system environment
    {:ok, config_path} = Provider.expand_path(config_path)
    # All applications are already loaded at this point
    if File.exists?(config_path) do
      config_path
      |> File.read!
      |> Jason.decode!
      |> persist()
    else
      :ok
    end
  end

  defp to_keyword(config) when is_map(config) do
    for {k, v} <- config do
      k = String.to_atom(k)
      {k, to_keyword(v)}
    end
  end
  defp to_keyword(config), do: config

  defp persist(config) when is_map(config) do
    config = to_keyword(config)
    for {app, app_config} <- config do
      base_config = Application.get_all_env(app)
      merged = merge_config(base_config, app_config)
      for {k, v} <- merged do
        Application.put_env(app, k, v, persistent: true)
      end
    end
    :ok
  end

  defp merge_config(a, b) do
    Keyword.merge(a, b, fn _, app1, app2 ->
      Keyword.merge(app1, app2, &merge_config/3)
    end)
  end
  defp merge_config(_key, val1, val2) do
    if Keyword.keyword?(val1) and Keyword.keyword?(val2) do
      Keyword.merge(val1, val2, &merge_config/3)
    else
      val2
    end
  end
end
```

See the module docs for `Distillery.Releases.Config.Provider` if you want to know more about the behaviour of these callbacks.
