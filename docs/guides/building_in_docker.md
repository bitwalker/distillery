# Building releases in Docker

There are many times where you want to build a release which targets an
environment other than your local machine. In this situation, it is recommended
to build your release in a Docker container which matches your target machine's
OS, kernel version, architecture, and system libraries. Docker makes this
trivial to accomplish with fairly minimal effort.

## Creating a build container

The general approach is to write a `Dockerfile` which sets up the image that
your release builds will take place in. This can be refreshed when system
libraries need to be updated, or for OS upgrades. An example of such an image
might look something like this:

```docker
FROM ubuntu:16.04

ENV REFRESHED_AT=2018-08-16 \
    LANG=en_US.UTF-8 \
    HOME=/opt/build \
    TERM=xterm

WORKDIR /opt/build

RUN \
  apt-get update -y && \
  apt-get install -y git wget vim locales && \
  locale-gen en_US.UTF-8 && \
  wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
  dpkg -i erlang-solutions_1.0_all.deb && \
  rm erlang-solutions_1.0_all.deb && \
  apt-get update -y && \
  apt-get install -y erlang elixir

CMD ["/bin/bash"]
```

We can build our image with the following command in the same directory as the `Dockerfile`:

```shell
$ docker build -t elixir-ubuntu:latest .
```

## Building releases

To actually build a release for our app, we need to mount the source code for
our app, mount a directory for the release tarball to be output to, then execute
a script which will build the release and copy the release tarball to that
directory.

First, our build script, in `bin/build`, would look something like this:

!!! warning
    Make sure `bin/build` is marked executable, with `chmod +x bin/build`

```bash
#!/usr/bin/env bash

set -e

cd /opt/build

APP_NAME="$(grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g')"
APP_VSN="$(grep 'version:' mix.exs | cut -d '"' -f2)"

mkdir -p /opt/build/rel/artifacts

# Install updated versions of hex/rebar
mix local.rebar --force
mix local.hex --if-missing --force

export MIX_ENV=prod

# Fetch deps and compile
mix deps.get
# Run an explicit clean to remove any build artifacts from the host
mix do clean, compile --force
# Build the release
mix distillery.release
# Copy tarball to output
cp "_build/prod/rel/$APP_NAME/releases/$APP_VSN/$APP_NAME.tar.gz" rel/artifacts/"$APP_NAME-$APP_VSN.tar.gz"

exit 0
```

To build our release and output it to `rel/artifacts`, we need to run the
following command:

```shell
$ docker run -v $(pwd):/opt/build --rm -it elixir-ubuntu:latest /opt/build/bin/build
```

This command will start our build container, execute the build script, then
exit. Once we are back at the command prompt, you should be able to see the
produced release tarball in the output of `ls rel/artifacts`

If you add dependencies that require system packages, you will need to update
the `Dockerfile` for the build container, and rerun the `docker build` command
to update it.

The tarball produced with this method can then be deployed to the target,
without needing to install Erlang on the target. The only requirement is that
any system packages the release depends on have been installed.
