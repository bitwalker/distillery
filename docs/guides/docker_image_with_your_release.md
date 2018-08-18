# Build a docker image with your release

## Build the image

Now that we have seen how to build a release, let's build one in a docker image. This is necessary for a deployment with Docker Swarm or Kubernetes for example.

Add a `dockerfile` to your project with the following content

```docker
# check https://hub.docker.com/_/elixir/ for the appropriate version of elixir you want to run
# alpine is used here to make dependency fetching faster
FROM elixir:1.7.2-alpine

# these arg command, set a default for the env variables
ARG APP_NAME=your_app_name
ARG MIX_ENV=prod
# use this variable in case you use an umbrella project
ARG PHOENIX_SUBDIR=.
ENV MIX_ENV ${MIX_ENV}
ENV REPLACE_OS_VARS true

# in linux the opt dir is used to put things not directly required by the os
WORKDIR /opt/app
# add git if one of your dependency pulls from git
RUN apk update \
  && apk --no-cache --update add nodejs yarn git build-base \
  && mix local.rebar --force \
  && mix local.hex --force
COPY . .
RUN mix do deps.get, deps.compile, compile

RUN cd ${PHOENIX_SUBDIR}/assets \
  && yarn install \
  && yarn deploy \
  && cd .. \
  && mix phx.digest
# we change the name of the start script here, just so this file can be copied and pasted
RUN mix release --env=${MIX_ENV} --verbose \
  && mv _build/prod/rel/${APP_NAME} /opt/release \
  && mv /opt/release/bin/${APP_NAME} /opt/release/bin/start_app

# minimal runtime image
FROM alpine:3.8
# bash is required by distillery
RUN apk update && apk --no-cache --update add bash openssl-dev
ENV REPLACE_OS_VARS true
WORKDIR /opt/app
COPY --from=0 /opt/release .
CMD ["/opt/app/bin/start_app", "foreground"]
```

Verify that you can build your image

Add the following `makefile` to your project

```makefile
BUILD ?= `git describe --always`
IMAGE ?= `grep 'app:' mix.exs | sed -e 's/ //g' -e 's/app://' -e 's/[:,]//g'`
VERSION ?= `grep 'version' mix.exs | sed -e 's/ //g' -e 's/version://' -e 's/[",]//g'`

image:
  docker build -t $(IMAGE):$(VERSION)-$(BUILD) .
```

Run `make` to build your image

!!!warning
    If you get the following error when running the makefile `makefile:6: *** multiple target patterns.  Stop.`, verify that the `docker build` has a tab and not spaces in front of it.

!!!info
    Yarn is optional, it is used instead of npm to reduce dependency fetching by a consequent amount of time.

!!!info
    We choose to handle environment variables in our application by replacing System.get_env("MY_VAR") with "${MY_VAR}" and Setting up REPLACE_OS_VARS to true. This will replace the env vars for us at runtime.

!!!info
    This is just the image for your application. If your application has external dependencies (like a database for example), it doesn't matter here, and will be handled in the deployment part of the guide.

!!!warning
    Make sure that the alpine image version you use, matches the one used in your elixir image. For example, elixir-1.7.2 is based on erlang-21 which is currently based on alpine-3.8. erlang-21 could be bumped to alpine-3.9 when it comes out.

## Verify it's working

add a config file in `./config/docker.env` with your configuration for example (these are common settings, fill in the ones for your app)

```Shell
HOSTNAME=my_hostname
SECRET_KEY_BASE=something_very_long_that_cannot_be_guessed_even_in_a_very_long_time
DB_HOSTNAME=my_db_hostname
DB_USER=my_db_username
DB_PASSWORD=my_db_username_password
DB_DB=my_db_name
PORT=4000
LANG=en_US.UTF-8
REPLACE_OS_VARS=true
ERLANG_COOKIE=my_erlang_cookie
```

add a `docker-compose.yml` file with the following

```docker
version: '3.5'

networks:
  webnet:
    driver: overlay
    attachable: true # this will be needed run particular commands in a container, for migrations for example


services:
  web:
    image: "my_image_name"
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
    ports:
      - "80:4000" # provided that we chose to run our app on port 4000 and we want to map to port 80
      - "443:443"
    volumes:
    - .:/app # your volumes if needed, for exemple if you have ssl certificates
    env_file:
     - ./config/docker.env # your env var file
    networks:
      - webnet
```

if you have external dependencies this is the place to add them. For example if you have a database, change your file to the following

```docker
version: '3.5'

networks:
  webnet:
    driver: overlay
    attachable: true


services:
  web:
    image: "my_image_name"
    depends_on:
      - db # note that the depends_on condition was added
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
    ports:
      - "80:4000"
      - "443:443"
    volumes:
    - .:/app
    env_file:
     - ./config/docker.dev.env
    networks:
      - webnet

# careful what you name your service here, these will be your database hostname in your env vars
  db:
    image: postgres:10-alpine
    deploy:
      replicas: 1
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: on-failure
    volumes:
      - "./volumes/postgres:/var/lib/postgresql/data"
    ports:
      - "5432:5432"
    env_file:
     - ./config/docker.env
    networks:
      - webnet
```

To deploy with docker swarm, you need to initialize the swarm with
`docker swarm init`

Then deploy your stack with
`docker stack deploy -c docker-compose.yml my_app_name`

go to localhost in your browser and verify that your app is working!
