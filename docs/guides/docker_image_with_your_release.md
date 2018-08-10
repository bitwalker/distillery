# Build a docker image with your release

Now that we have seen how to build a release, let's build one in a docker image. This is necessary for a deployment with docker swarm or kubernetes for example.

A prerequisite step to this, is to initialize your release (`mix release.init`) and configure your [vm.args](/files/vm.args).

once that is done add a `dockerfile` to your project with the following content

```
# check https://hub.docker.com/_/elixir/ for the appropriate version of elixir you want to run
# alpine is used here to make dependency fetching faster
FROM elixir:1.7.2-alpine

# these arg command, set a default for the env variables
ARG APP_NAME=your_app_name
ARG MIX_ENV=prod
ARG APP_VERSION=0.0.0
# use this variable in case you use an umbrella project
ARG PHOENIX_SUBDIR=.
ENV MIX_ENV ${MIX_ENV}
ENV APP_VERSION ${APP_VERSION}
# We choose to handle environment variables in our application by replacing System.get_env("MY_VAR")
# with "${MY_VAR}". Setting up REPLACE_OS_VARS to true, will replace the values for us.
ENV REPLACE_OS_VARS true

# in linux the opt dir is used to put things not directly required by the os
WORKDIR /opt/app
# use yarn instead of npm to reduce dependency fetching by a lot (from 180s to 60s on my machine on my project)
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

- this is just the image for your application. If your application has external dependencies (like a database for example), it doesn't matter here, and will be handled in the deployment part of the guide.
- Make sure that the alpine image version you use, matches the one used in your elixir image. For example, elixir-1.7.2 is based on erlang-21 which is currently based on alpine-3.8. erlang-21 could be bumped to alpine-3.9 when it comes out.
