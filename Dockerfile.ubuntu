FROM ubuntu:16.04

ENV REFRESHED_AT=2018-08-16 \
    LANG=en_US.UTF-8 \
    HOME=/opt/app \
    TERM=xterm

WORKDIR /opt

RUN \
  mkdir -p /opt/distillery && \
  mkdir -p /opt/distillery-test && \
  apt-get update -y && \
  apt-get install -y git wget vim locales && \
  locale-gen en_US.UTF-8 && \
  wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
  dpkg -i erlang-solutions_1.0_all.deb && \
  apt-get update -y && \
  apt-get install -y erlang elixir && \
  mix local.rebar --force && \
  mix local.hex --force && \
  pushd /opt && \
  git clone https://github.com/bitwalker/distillery-test && \
  popd

CMD ["/bin/bash"]
