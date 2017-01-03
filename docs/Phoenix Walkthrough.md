## Phoenix Walkthrough

It is recommended that you review the [Advanced Deployment Guide](http://phoenixframework.org/docs/advanced-deployment),
which covers Phoenix-specific configuration that needs to be provided in order for your application to work within a release.
The guide currently references Exrm, but it is an almost identical process with Distillery. I would recommend skipping over
those parts, and focus on what you need to do to prepare your application. The guide below will walk you through everything in
more detail.

The goal of this guide is to walk you through the basics of deploying
a simple Phoenix application with Distillery. We are going to build a
simple Phoenix application from scratch and take it through 4
releases. 1 main release, and 3 hot upgrade releases.

**NOTE** At this time this guide does not cover
[Ecto](https://github.com/elixir-ecto/ecto)'s use in releases. This
will be added at a later time.

### First Steps

First off we will create a new Phoenix app (without Ecto) using `mix
phoenix.new --no-ecto phoenix_distillery`. Go ahead and fetch
dependencies when prompted by the mix task.

Don't forget to run an `npm install` from within your project
directory in order to install brunch and its dependencies!

Next we will install distillery in our `mix.exs`

*file: mix.exs*
```elixir
  defp deps do
    [ ...,
     {:distillery, "~> MAJ.MIN"},
      ...,
    ]
  end
```

Execute a `mix do deps.get, compile` and you are ready to continue.

### Distillery Configuration

To initialize Distillery, run `mix release.init`. Please refer to the
Distillery walkthrough for a detailed look at the configuration
options available.

We will need to configure the `prod` environment before we start
building releases.

*NOTE*: If you run `mix release` with `MIX_ENV=dev` (the default), then you must also ensure
that you set `code_reloader: false` in your configuration. If you do not, you'll get a failure
at runtime about being unable to start `Phoenix.CodeReloader.Server` because it depends on Mix,
which is not intended to be packaged in releases. As you won't be doing code reloading in a release
(at least not with the same mechanism), you must disable this.

*file: config/prod.exs*
```elixir
config :phoenix_distillery, PhoenixDistillery.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "localhost", port: {:system, "PORT"}], # This is critical for ensuring web-sockets properly authorize.
  cache_static_manifest: "priv/static/manifest.json",
  server: true,
  root: ".",
  version: Mix.Project.config[:version]
```

Let's discuss each of these options.

- `server` configures the endpoint to boot the
  [Cowboy](https://github.com/ninenines/cowboy) application http
  endpoint on start.
- `root` configures the application root for serving static files
- `version` ensures that the asset cache will be busted on *versioned*
  application upgrades (more on this later)

**NOTE** We are telling our release to use ENV variables by providing
the tuple `{:system, "PORT"}` to the port option. Your release will
not start properly if the `PORT` variable is not available to it on
the production machine/in the production environment.


### Version 0.0.1

Before we modify our app at all, we will generate a release with the
current state. We will generate a release. Our release command is 3
separate commands which I have linked with `&&`:

`./node_modules/brunch/bin/brunch b -p && MIX_ENV=prod mix do phoenix.digest, release --env=prod`

1. `./node_modules/brunch/bin/brunch b -p` builds your assets in
   production mode. More detail can be found in the
   [Phoenix Static Asset Guide](http://www.phoenixframework.org/docs/static-assets)
1. `MIX_ENV=prod mix phoenix.digest` To compress and tag your assets
    for proper caching. More detail can be found in the
    [Phoenix Mix Task Guide](http://www.phoenixframework.org/docs/mix-tasks#section--mix-phoenix-digest-)
1. `MIX_ENV=prod mix release --env=prod` To actually generate a release for a
    production environment


**NOTE**: Q: Why are we building a prod release? A: It does not make
much sense to build a dev release with a Phoenix project; `dev` mode
is supposed to be interactive with features such as live reload and
automatic `brunch` asset recompilation. In order to turn off these
features to build a release of the `dev` environment you might as well
just use your `prod` configuration.


Create a new directory somewhere on your machine called `local_deploy`
and copy the release tarball you just created into it. Your command
should look something like this:

`cp _build/prod/rel/phoenix_distillery/releases/0.0.1/phoenix_distillery.tar.gz local_deploy/`

Now `cd` into `local_deploy` and extract the tarball with:

`tar xvf phoenix_distillery.tar.gz`

Your application is ready to be started up with the following command:

`PORT=4000 ./bin/phoenix_distillery start`

Notice that we are explicitly setting the `PORT` environment variable
in this shell session.

If all has gone well, you should be able to open `localhost:4000` in
your browser and see the default Phoenix landing page in all its
glory.

### Version 0.0.2

For version 0.0.2, we are going to remove the Phoenix logo from the
landing page and upgrade our application.

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

*file: web/static/css/app.css*
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

*file: web/templates/layout/app.html.eex*
```html
<span class="logo"></span>
```

Next we build an upgrade release with the following command:

`./node_modules/brunch/bin/brunch b -p && MIX_ENV=prod mix do phoenix.digest, release --env=prod --upgrade`

This is the same command as in version 0.0.1 with the exception of
`--upgrade`. The upgrade flag tells Distillery to build an
[appup](https://hexdocs.pm/distillery/upgrades-and-downgrades.html)
for every application included in the release. These files are then
used to generate a
[relup](https://hexdocs.pm/distillery/upgrades-and-downgrades.html)
which details how an upgrade (or downgrade) is applied to a running
application instance.

If all went as planned, you now have a 0.0.2 release in
`_build/prod/rel/phoenix_distillery/releases/`. In order to deploy this tarball,
you need to create a `0.0.2` directory in `local_deploy/releases` and
copy the 0.0.2 tarball into this directory. Your copy command should
look something like this:

`cp _build/prod/rel/phoenix_distillery/releases/0.0.2/phoenix_distillery.tar.gz local_deploy/releases/0.0.2`

Now all you have to do is upgrade your running instance by executing
`local_deploy/bin/phoenix_distillery upgrade 0.0.2`. If you go reload
your browser you will see that the logo has now disappeared!

### Version 0.0.3

For version 0.0.3, we are going to do something more fancy. We are
going to setup a web socket which emits even numbers. The client will
connect on page load and display these numbers in the console.

First we need to create a channel on the server responsible for
emitting even numbers:

*new file:   web/channels/heartbeat_channel.ex*
```elixir
defmodule PhoenixDistillery.HeartbeatChannel do
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

Now we need to modify the default `user_socket` to reference the
`HeartbeatChannel` we just created. The only defined channel should be
`heartbeat:*`

*file: web/channels/user_socket.ex*
```elixir
defmodule PhoenixDistillery.UserSocket do
   use Phoenix.Socket
   channel "heartbeat:*", PhoenixDistillery.HeartbeatChannel

   ...
end
```

Now we need to enable the default socket and tell it how to handle our
heartbeat message:

*file: web/static/js/app.js*
```javascript
import "deps/phoenix_html/web/static/js/phoenix_html"
import socket from "./socket"
```

*file: web/static/js/socket.js*
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


With all that complete, we are now ready to generate the 0.0.3 release
just as we did with 0.0.2. So we will generate a release, copy the
0.0.3 tarball into a new release directory under `local_deploy`, and
upgrade the application.

1. `./node_modules/brunch/bin/brunch b -p && MIX_ENV=prod mix do phoenix.digest, release --env=prod --upgrade`
1. `cp _build/prod/rel/phoenix_distillery/releases/0.0.3/phoenix_distillery.tar.gz local_deploy/releases/0.0.3`
1. `./local_deploy/bin/phoenix_distillery upgrade 0.0.3`

If you go reload your browser and open your console you will be
greeted by a series of increasing numbers from 0!

### Version 0.0.4

For version 0.0.4, we are going to modify the web socket we created in
version 0.0.3 to increment the heartbeat state by 1 instead of
two. This is a great demonstration of how web sockets remain open
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

*new file:   web/channels/heartbeat_channel.ex*
```elixir
defmodule PhoenixDistillery.HeartbeatChannel do
  ...

  def handle_info({:beat, i}, socket) do
    broadcast!(socket, "ping", %{body: i})
    Process.send_after(self, {:beat, i + 1}, 2000)
    {:noreply, socket}
  end

  ...
end
```

With this complete, we are now ready to generate the 0.0.4 release
just as we did with 0.0.3. Generate a release, copy the 0.0.4 tarball
into a new release directory under `local_deploy`, and upgrade the
application.

1. `./node_modules/brunch/bin/brunch b -p && MIX_ENV=prod mix do phoenix.digest, release --env=prod --upgrade`
1. `cp _build/prod/rel/phoenix_distillery/releases/0.0.4/phoenix_distillery.tar.gz local_deploy/releases/0.0.4`
1. `./local_deploy/bin/phoenix_distillery upgrade 0.0.4`

*DO NOT RELOAD YOUR BROWSER* Simply stare at your console and wait. In
no time at all you will see numbers start incrementing by 1 rather
than 2. You will conclude that hot upgrades are the coolest thing
since sliced bread.

### Conclusion

Hopefully this has been a good introduction to using Distillery with
Phoenix. There is more ground to cover (especially with Ecto) which
will be added as the project progresses.

Happy Hacking
