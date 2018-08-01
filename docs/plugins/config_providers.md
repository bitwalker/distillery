# Custom Configuration Providers

Distillery now provides the capability to implement custom configuration
providers for loading and persisting runtime configuration during boot. These
providers are able to replace the use of `sys.config` and `config.exs` if
desired. The one exception is if you need to configure the `:kernel`
application, you will need to do so via `sys.config`, `config.exs`, or `vm.args`.

## Implementing A Provider

To implement a new configuration provider, there are two callbacks you need to
implement currently, `init/1` and `get/1`.

The `init/1` function is called during startup, before any applications are
started, with the exception of core applications required for things to work,
namely `:kernel`, `:stdlib`, `:compiler`, and `:elixir`. Everything is loaded in
a release, but you may still want to be explicit about loading applications just
in case the provider ends up running in a relaxed code loading environment.

Currently, `get/1` is not used by anything directly, but you can use it yourself
to ask for a configured value, simply by calling
`Mix.Releases.Config.Provider.get/1`. This will try all of the config providers
until one returns a non-nil value, or nil if no value was found. I am
considering some features which may take advantage of this API in the future,
but currently it is just a placeholder.

There are some important properties you must keep in mind when designing and 
implementing a provider:

- You have access to the code of all applications in the release, _but_, only
  `:kernel`, `:stdlib`, `:compiler`, and `:elixir` are started when the
  provider's `init` callback is invoked.
- If you must start an application in order to accomplish some goal, at present,
  you must manually start them with `Application.start/2`, and before returning
  from `init`, you must stop them with `Application.stop/1`. If you do not do
  this, the boot script will fail when attempting to start the release
  post-configuration.
- If you need to start an application to run the provider, and the application
  needs configuration, you have a circular dependency problem. In order to solve
  this, you need to have users provide the initial configuration via
  `sys.config` or `config.exs`, that way you can bootstrap the provider.
  
In general, it is highly recommended to avoid starting applications as part of
your provider. The one exception to this is providers which may make HTTP
requests, as some applications are necessary to start in that case if using `:httpc`,
namely `:inets`, and possibly `:crypto` and `:ssl`. In a future release,
Distillery may make it possible to express application dependencies like this,
so that configuration can either be moved to take place after they are started,
or have Distillery manage their temporary lifecycle for you.

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
  use Mix.Releases.Config.Provider

  def init([config_path]) do
    # Helper which expands paths to absolute form
    # and expands env vars in the path of the form `${VAR}`
    # to their value in the system environment
    config_path = Provider.expand_path(config_path)
    # All applications are already loaded at this point
    if File.exists?(config_path) do
      config_path
      |> Jason.decode!
      |> to_keyword()
      |> persist()
    else
      :ok
    end
  end

  defp to_keyword(config) when is_map(config) do
    for {k, v} <- config do
      k = String.to_atom(k)
      {k, to_keyword(config)}
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

See the module docs for `Mix.Releases.Config.Provider` if you want to know more about the behaviour of these callbacks.
