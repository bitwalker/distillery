FROM bitwalker/alpine-elixir:latest

ENV REFRESHED_AT=2018-08-16

WORKDIR /opt

RUN \
  mkdir -p /opt/distillery && \
  mkdir -p /opt/distillery-test && \
  mix local.rebar --force && \
  mix local.hex --force && \
  git clone https://github.com/bitwalker/distillery-test

CMD ["/bin/bash"]
