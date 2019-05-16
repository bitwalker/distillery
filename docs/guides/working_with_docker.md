# Deploying with Docker

It is becoming more and more common to deploy containerized applications -
releases are well suited for these environments as well!

This guide will walk you through the best way to automate the build of a Docker
image containing just your release. By avoiding the need to include build tools
and other compile-time concerns in the final image, the images are lighter and
the attack surface is smaller. When combined with base images like Alpine Linux,
you can even further reduce the size and attack surface of the final image.

!!! info
    This guide assumes you are already familiar with building a release, if you
    have not seen how to do that, I would recommend visiting the
    [Walkthrough](../introduction/walkthrough.md) guide first.

!!! tip
    If you'd like to see an example project which makes uses of the information
    in this guide, check out
    [distillery-test](https://github.com/bitwalker/distillery-test). It's a
    great way to try things out without needing to create a new project!

## The Dockerfile

In the root of your project, create a new file named `Dockerfile` with the
following content:

```docker
# The version of Alpine to use for the final image
# This should match the version of Alpine that the `elixir:1.7.2-alpine` image uses
ARG ALPINE_VERSION=3.8

FROM elixir:1.7.2-alpine AS builder

# The following are build arguments used to change variable parts of the image.
# The name of your application/release (required)
ARG APP_NAME
# The version of the application we are building (required)
ARG APP_VSN
# The environment to build with
ARG MIX_ENV=prod
# Set this to true if this release is not a Phoenix app
ARG SKIP_PHOENIX=false
# If you are using an umbrella project, you can change this
# argument to the directory the Phoenix app is in so that the assets
# can be built
ARG PHOENIX_SUBDIR=.

ENV SKIP_PHOENIX=${SKIP_PHOENIX} \
    APP_NAME=${APP_NAME} \
    APP_VSN=${APP_VSN} \
    MIX_ENV=${MIX_ENV}

# By convention, /opt is typically used for applications
WORKDIR /opt/app

# This step installs all the build tools we'll need
RUN apk update && \
  apk upgrade --no-cache && \
  apk add --no-cache \
    nodejs \
    yarn \
    git \
    build-base && \
  mix local.rebar --force && \
  mix local.hex --force

# This copies our app source code into the build container
COPY . .

RUN mix do deps.get, deps.compile, compile

# This step builds assets for the Phoenix app (if there is one)
# If you aren't building a Phoenix app, pass `--build-arg SKIP_PHOENIX=true`
# This is mostly here for demonstration purposes
RUN if [ ! "$SKIP_PHOENIX" = "true" ]; then \
  cd ${PHOENIX_SUBDIR}/assets && \
  yarn install && \
  yarn deploy && \
  cd - && \
  mix phx.digest; \
fi

RUN \
  mkdir -p /opt/built && \
  mix distillery.release --verbose && \
  cp _build/${MIX_ENV}/rel/${APP_NAME}/releases/${APP_VSN}/${APP_NAME}.tar.gz /opt/built && \
  cd /opt/built && \
  tar -xzf ${APP_NAME}.tar.gz && \
  rm ${APP_NAME}.tar.gz

# From this line onwards, we're in a new image, which will be the image used in production
FROM alpine:${ALPINE_VERSION}

# The name of your application/release (required)
ARG APP_NAME

RUN apk update && \
    apk add --no-cache \
      bash \
      openssl-dev

ENV REPLACE_OS_VARS=true \
    APP_NAME=${APP_NAME}

WORKDIR /opt/app

COPY --from=builder /opt/built .

CMD trap 'exit' INT; /opt/app/bin/${APP_NAME} foreground
```

!!! tip
    This guide uses Alpine Linux, but you can use a different base image, you
    can find official Elixir base images [here](https://hub.docker.com/_/elixir).

!!! warning 
    Make sure that the version of Linux that you use for the final image
    matches the one used by the builder image (in this case,
    `elixir:1.7.2-alpine`, which uses Alpine Linux 3.8). If you use a different
    version, the release may not work, since the Erlang runtime was built
    against a different version of libc (or musl in Alpine's case)

!!! info
    Our use of `yarn` above is optional, you can use whatever your project uses, 
    just modify the Dockerfile as necessary. The choice to use `yarn` over `npm`
    is to take advantage of Yarn's significantly faster dependency fetching.

!!! tip
    While this Dockerfile enables `REPLACE_OS_VARS`, you will probably want to
    take advantage of the config provider for `Mix.Config` instead, see the [Handling
    Configuration](../config/runtime.md) document for more information.

To prevent reperforming steps when not necessary, add a `.dockerignore` to your project with the following:

```
_build/
deps/
.git/
.gitignore
Dockerfile
Makefile
README*
test/
priv/static/
```

Feel free to extend it as necessary - ideally you want to ignore anything not involved in the build.
    
## Building the image

To help automate building images, it is recommended to use a Makefile or shell
script. I prefer to use Makefiles for this purpose generally. The following is
a simple Makefile which will build our image, and produces friendly help output
when you run just `make` in the project directory:

```makefile
.PHONY: help

APP_NAME ?= `grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g'`
APP_VSN ?= `grep 'version:' mix.exs | cut -d '"' -f2`
BUILD ?= `git rev-parse --short HEAD`

help:
	@echo "$(APP_NAME):$(APP_VSN)-$(BUILD)"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build --build-arg APP_NAME=$(APP_NAME) \
		--build-arg APP_VSN=$(APP_VSN) \
		-t $(APP_NAME):$(APP_VSN)-$(BUILD) \
		-t $(APP_NAME):latest .

run: ## Run the app in Docker
	docker run --env-file config/docker.env \
		--expose 4000 -p 4000:4000 \
		--rm -it $(APP_NAME):latest
```

Now that those files have been created, we can build our image! The next step is
to run the build:

```
$ make build
```

!!! warning
    If `make` reports an error mentioning `multiple target patterns`, you need
    to ensure the Makefile is formatted with **tabs not spaces**.

If `make` ran successfully, you now have a production-ready image!

## Running the image

Our next step is to test out our image! We're going to assume that your app was
built using the config provider for `Mix.Config`, which would look like the
following in your `rel/config.exs`:

```elixir
release :myapp do
  # snip..
  set config_providers: [
    {Distillery.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/config.exs"]}
  ]
  set overlays: [
    {:copy, "rel/config/config.exs", "etc/config.exs"}
  ]
end
```

The config file referenced here (`rel/config/config.exs`) should look something
like the following:

```elixir
use Mix.Config

config :myapp, MyApp.Repo,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  database: System.get_env("DATABASE_NAME"),
  hostname: System.get_env("DATABASE_HOST"),
  pool_size: 15

port = String.to_integer(System.get_env("PORT") || "8080")
config :myapp, MyApp.Endpoint,
  http: [port: port],
  url: [host: System.get_env("HOSTNAME"), port: port],
  root: ".",
  secret_key_base: System.get_env("SECRET_KEY_BASE")
```

For convenience when testing locally, create a file, `config/docker.env`, with
the content below:

```shell
HOSTNAME=localhost
SECRET_KEY_BASE="u1QXlca4XEZKb1o3HL/aUlznI1qstCNAQ6yme/lFbFIs0Iqiq/annZ+Ty8JyUCDc"
DATABASE_HOST=db
DATABASE_USER=postgres
DATABASE_PASS=postgres
DATABASE_NAME=myapp_db
PORT=4000
LANG=en_US.UTF-8
REPLACE_OS_VARS=true
ERLANG_COOKIE=myapp
```

This file will be used to automatically export all of the system environment
variables used to configure our application.

We're going to use Docker Compose for running our app locally, so create another
file in the project root, called `docker-compose.yml`, with the following content:

```docker
version: '3.5'

services:
  web:
    image: "myapp:latest"
    ports:
      - "80:4000" # In our .env file above, we chose port 4000
    env_file:
      - config/docker.env
```

Notice above that we are telling Docker Compose to use the `docker.env` file we
created above, this is how those values end up exported in the running container.

If we depend on other services, a database for example, we can start them here
as well. First, we just need to add the service description for the database:

```docker
db:
  image: postgres:10-alpine
  volumes:
    - "./volumes/postgres:/var/lib/postgresql/data"
  ports:
    - "5432:5432"
  env_file:
    - config/docker.env
```

!!! warning
    Be careful what you name the service! This name will be the hostname used to
    talk to the service. In this case, it will be `db`. You will also need to
    make sure the name used matches what is in `config/docker.env`.
    
Notice again that we're feeding the service `docker.env` so that we can
configure it.

The only other step needed is to make `db` a dependency for `web`, like so:

```docker
services:
  web:
    depends_on:
      - db
    # snip..
```

To start everything, simply run `docker-compose up` or `docker-compose up -d` if
you want to start as a daemon.

You should now be able to open your browser to `http://localhost:4000` to see
the running app.

!!! tip
    You can also use Docker Swarm, by first initializing Swarm: 
    
    ```
    $ docker swarm init
    ```
    
    And then deploying a new stack:
    
    ```
    $ docker stack deploy -c docker-compose.yml myapp
    ```
    
    This approach requires some minimal adjustments to our `docker-compose.yml`
    file, see the [Deploying To Digital Ocean](deploying_to_digital_ocean.md)
    guide to learn more.
