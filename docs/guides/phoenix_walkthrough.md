# Phoenix Walkthrough

It is recommended that you review the [Deployment Guide](https://hexdocs.pm/phoenix/deployment.html#content),
which covers Phoenix specific configurations that need to be provided in order for your application to work within a release. The guide below will walk you through a working example of using Distillery with a Phoenix 1.3 application to create a release.

The goal of this guide is to walk you through the basics of deploying a simple Phoenix application with Distillery. We are going to build a simple Phoenix, 1.3, application from scratch and take it through 4 releases. 1 main release, and 3 hot upgrade releases.

**NOTE** At this time this guide does not cover [Ecto](https://github.com/elixir-ecto/ecto)'s use in releases. This will be added at a later time.

### Create Phoenix App with Distillery

First off we will create a new Phoenix app (without Ecto) and then change into the newly created directory with the following commands:
```
$ mix phx.new --no-ecto phoenix_distillery
$ cd phoenix_distillery
```

Next we will add Distillery to the deps function of our `mix.exs` file.

*file: mix.exs*
```elixir
  defp deps do
    [ ...,
     {:distillery, "~> 2.0"},
      ...,
    ]
  end
```

### Distillery Configuration

First let's modify the Phoenix `config/prod.exs` file. Change this section of text:

```elixir
config :phoenix_distillery, PhoenixDistilleryWeb.Endpoint,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"
```

to the following:

```elixir
config :phoenix_distillery, PhoenixDistilleryWeb.Endpoint,
  http: [:inet6, port: {:system, "PORT"}],
  url: [host: "localhost", port: {:system, "PORT"}], # This is critical for ensuring web-sockets properly authorize.
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",
  version: Application.spec(:phoenix_distillery, :vsn)
```

We also need to change the secret key base in `config/prod.secret.exs` . Change this section of text:

```elixir
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """
```

to the following:

```elixir
secret_key_base =
  "5U8dBbveeM1DMJtFZq6Ybaum394cVHDHHj/YnKo8r8461WS9eFDWT2YpLzuODsan"
```

**NOTE** The secret key base should be generated using `mix phx.gen.secret`. It
should also not be committed to your VCS in plain text.

Let's discuss these options.

- `server` configures the endpoint to boot the [Cowboy](https://github.com/ninenines/cowboy) application http endpoint on start.
- `root` configures the application root for serving static files
- `version` ensures that the asset cache will be busted on *versioned* application upgrades (more on this later)

**NOTE** We are telling our release to use an ENV variable (PORT) by providing the tuple `{:system, "PORT"}` to the port option. Your release will not start properly if the `PORT` variable is not available to it on the production machine/in the production environment.

### Building a Release

Now we have the Phoenix app created with Distillery and our configuration all ready for building a release. Execute the following commands:

```
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile
$ npm run deploy --prefix assets
$ mix phx.digest
```

The above commands are not unique to Distillery, they are required by Phoenix to build a production release and get all the static files in order.

#### Distillery Release

The following initializes Distillery for the project:
```
$ mix distillery.init
```

The above command will create the file `rel/config.exs` in addition to an empty directory `rel/plugins/`. Please refer to the Distillery [walkthrough](https://github.com/bitwalker/distillery/blob/master/docs/Walkthrough.md) for a detailed look at the configuration options available.

To build the release the following command is executed:

```
$ MIX_ENV=prod mix distillery.release
```

To run your release, execute the following command:
```
$ PORT=4001 _build/prod/rel/phoenix_distillery/bin/phoenix_distillery foreground
```

You should be able to go to [localhost:4001](localhost:4001) and load the default Phoenix application.

*NOTE* The above commands can be combined into one quick command as
```
$ npm run deploy --prefix assets && MIX_ENV=prod mix do phx.digest, release --env=prod
```

*NOTE*: If you run `mix distillery.release` with `MIX_ENV=dev` (the default), then you must also ensure that you set `code_reloader: false` in your configuration. If you do not, you'll get a failure at runtime about being unable to start `Phoenix.CodeReloader.Server` because it depends on Mix, which is not intended to be packaged in releases. As you won't be doing code reloading in a release (at least not with the same mechanism), you must disable this.


### Version 0.0.1

If you followed the above you will have generated a working release. A few notes on some of the above commands we used:

- `npm run deploy --prefix assets` builds your assets in
   production mode. More detail can be found in the
   [Phoenix Static Asset Guide](http://phoenixframework.org/blog/static-assets)
- `MIX_ENV=prod mix phx.digest` To compress and tag your assets
    for proper caching. More detail can be found in the
    [Phoenix Mix Task Guide](https://hexdocs.pm/phoenix/Mix.Tasks.Phoenix.Digest.html)
- `MIX_ENV=prod mix distillery.release --env=prod` To actually generate a release for a
    production environment

You might wonder "why all the hassle to build a release?" A Phoenix project in `dev` mode is
supposed to be interactive with features such as live code reload and automatic `webpack` asset
recompilation and extra logging. While great for development, it comes at a performance cost
and you would not want to run a production Phoenix application in dev mode.


#### Take that Release Anywhere

Create a new directory somewhere on your machine called `local_deploy` and copy the release tarball you just created into it. Your command should look something like this:

`cp _build/prod/rel/phoenix_distillery/releases/0.0.1/phoenix_distillery.tar.gz local_deploy/`

Now `cd` into `local_deploy` and extract the tarball with:

`tar xvf phoenix_distillery.tar.gz`

Your application is ready to be started up with the following command:

`PORT=4001 ./bin/phoenix_distillery start`

Notice that we are explicitly setting the `PORT` environment variable in this shell session.

If all has gone well, you should be able to open `localhost:4001` in your browser and see the default Phoenix landing page in all its glory.

### Version 0.0.2

For version 0.0.2, we are going to remove the Phoenix logo from the landing page and upgrade our application.

*file: mix.exs*
```elixir
def project do
   [
    ...
    version: "0.0.2", # Bumping our version here
    ...
   ]
end
```

Remove the logo class from our application.css

*file: assets/css/phoenix.css*
```css
// We remove the following block of css
.logo {
  width: 519px;
  height: 71px;
  display: inline-block;
  margin-bottom: 1em;
  background-image: url("/images/phoenix.png");
  background-size: 519px 71px;
}

```

Remove the following line from our application layout.

*file: lib/phoenix_distillery_web/templates/layout/app.html.eex*

```html
<span class="logo"></span>
```

Next we build an upgrade release with the following command:

`npm run deploy --prefix assets && MIX_ENV=prod mix do phx.digest, release --env=prod --upgrade`

This is the same command as in version 0.0.1 with the exception of `--upgrade`. The upgrade flag tells Distillery to build an [appup](https://hexdocs.pm/distillery/guides/upgrades_and_downgrades.html) for every application included in the release. These files are then used to generate a [relup](https://hexdocs.pm/distillery/guides/upgrades_and_downgrades.html) which details how an upgrade (or downgrade) is applied to a running application instance.

If all went as planned, you now have a 0.0.2 release in `_build/prod/rel/phoenix_distillery/releases/`. In order to deploy this tarball, you need to create a `0.0.2` directory in `local_deploy/releases` and copy the 0.0.2 tarball into this directory. Your copy command should look something like this:

`cp _build/prod/rel/phoenix_distillery/releases/0.0.2/phoenix_distillery.tar.gz local_deploy/releases/0.0.2/`

Now all you have to do is upgrade your running instance by executing `./local_deploy/bin/phoenix_distillery upgrade 0.0.2`. If you go reload your browser you will see that the logo has now disappeared!

### Version 0.0.3

For version 0.0.3, we are going to do something more fancy. We are going to setup a web socket which emits even numbers. The client will connect on page load and display these numbers in the console.

First we need to create a channel on the server responsible for emitting even numbers:

*new file:   lib/phoenix_distillery_web/channels/heartbeat_channel.ex*
```elixir
defmodule PhoenixDistilleryWeb.HeartbeatChannel do
  use Phoenix.Channel

  def join("heartbeat:listen", _message, socket) do
    send(self, :after_join) # send a message to kick off our loop. We do this in order to take as little time as possible on the server before we send the client socket an :ok message signaling a good connection.
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    send(self, {:beat, 0}) # initialize our heartbeat broadcast with an initial state of 0
    {:noreply, socket}
  end

  def handle_info({:beat, i}, socket) do
    broadcast!(socket, "ping", %{body: i}) # broadcast the current heartbeat number to all connected clients
    Process.send_after(self, {:beat, i + 2}, 2000) # send a message to the current server with a new (even numbered) state after 2 seconds
    {:noreply, socket}
  end

end
```

Now we need to modify the default `user_socket` to reference the `HeartbeatChannel` we just created. The only defined channel should be `heartbeat:*`

*file: lib/phoenix_distillery_web/channels/user_socket.ex*
```elixir
defmodule PhoenixDistilleryWeb.UserSocket do
   use Phoenix.Socket
   channel "heartbeat:*", PhoenixDistilleryWeb.HeartbeatChannel

   ...
end
```

Now we need to enable the default socket and tell it how to handle our heartbeat message:

*file: assets/js/app.js*
```javascript
import "phoenix_html"
import socket from "./socket"
```

*file: assets/js/socket.js*
```javascript
...
let socket = new Socket("/socket", {params: {token: window.userToken}})
socket.connect()

let channel = socket.channel("heartbeat:listen", {})
channel.join()
channel.on("ping", payload => { console.log(payload.body) })
...
```

Finally we need to bump our version to 0.0.3 in `mix.exs`

*file: mix.exs*
```elixir
def project do
   [
    ...
    version: "0.0.3", # Bumping our version here
    ...
   ]
end
```


With all that complete, we are now ready to generate the 0.0.3 release just as we did with 0.0.2. So we will generate a release, copy the 0.0.3 tarball into a new release directory under `local_deploy`, and upgrade the application.

- `npm run deploy --prefix assets && MIX_ENV=prod mix do phx.digest, release --env=prod --upgrade`
- `mkdir local_deploy/releases/0.0.3`
- `cp _build/prod/rel/phoenix_distillery/releases/0.0.3/phoenix_distillery.tar.gz local_deploy/releases/0.0.3/`
- `./local_deploy/bin/phoenix_distillery upgrade 0.0.3`

If you go reload your browser and open your console you will be greeted by a series of increasing numbers from 0!

### Version 0.0.4

For version 0.0.4, we are going to modify the web socket we created in version 0.0.3 to increment the heartbeat state by 1 instead of two. This is a great demonstration of how web sockets remain open
during a hot upgrade.

First bump your version to 0.0.4 in `mix.exs`

*file: mix.exs*
```elixir
def project do
   [
    ...
    version: "0.0.4", # Bumping our version here
    ...
   ]
end
```

Next update the `HeartbeatChannel` to emit numbers incremented by one:

*new file:   lib/phoenix_distillery_web/channels/heartbeat_channel.ex*
```elixir
defmodule PhoenixDistilleryWeb.HeartbeatChannel do
  ...

  def handle_info({:beat, i}, socket) do
    broadcast!(socket, "ping", %{body: i})
    Process.send_after(self, {:beat, i + 1}, 2000)
    {:noreply, socket}
  end

  ...
end
```

With this complete, we are now ready to generate the 0.0.4 release just as we did with 0.0.3. Generate a release, copy the 0.0.4 tarball into a new release directory under `local_deploy`, and upgrade the application.

- `npm run deploy --prefix assets && MIX_ENV=prod mix do phx.digest, release --env=prod --upgrade`
- `mkdir local_deploy/releases/0.0.4`
- `cp _build/prod/rel/phoenix_distillery/releases/0.0.4/phoenix_distillery.tar.gz local_deploy/releases/0.0.4/`
- `./local_deploy/bin/phoenix_distillery upgrade 0.0.4`

*DO NOT RELOAD YOUR BROWSER* Simply stare at your console and wait. In no time at all you will see numbers start incrementing by 1 rather than 2. You will conclude that hot upgrades are the coolest thing since sliced bread.

### Conclusion

Hopefully this has been a good introduction to using Distillery with Phoenix. There is more ground to cover (especially with Ecto) which will be added as the project progresses.

Happy Hacking
