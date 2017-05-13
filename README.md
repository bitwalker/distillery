# Distillery

[![Master](https://travis-ci.org/bitwalker/distillery.svg?branch=master)](https://travis-ci.org/bitwalker/distillery)
[![Hex.pm Version](http://img.shields.io/hexpm/v/distillery.svg?style=flat)](https://hex.pm/packages/distillery)
[![Coverage Status](https://coveralls.io/repos/github/bitwalker/distillery/badge.svg?branch=master)](https://coveralls.io/github/bitwalker/distillery?branch=master)

Every alchemist requires good tools, and one of the greatest tools in the alchemist's disposal
is the distillery. The purpose of the distillery is to take something and break it down to its
component parts, reassembling it into something better, more powerful. That is exactly
what this project does - it takes your Mix project and produces an Erlang/OTP release, a
distilled form of your raw application's components; a single package which can be deployed anywhere,
independently of an Erlang/Elixir installation. No dependencies, no hassle.

This is a pure-Elixir, dependency-free implementation of release generation for Elixir projects.
It is currently a standalone package, but may be integrated into Mix at some point in the future.

## Installation

Distillery requires Elixir 1.3 or greater. It works with Erlang 18+.

```elixir
defp deps do
  [{:distillery, "~> 1.4"}]
end
```

Just add as a mix dependency and use `mix release`. This is a replacement for exrm, but is in beta at this time.

If you are new to releases, please review the [documentation](https://hexdocs.pm/distillery).

## Community/Questions/etc.

If you have questions or want to discuss Distillery, releases, or other deployment
related topics, a good starting point is the Deployment section of ElixirForum, which
can be found [here](https://elixirforum.com/c/popular-topics/deployment).

I can often be found in IRC on freenode, in the `#elixir-lang` channel, and there is
also an [Elixir Slack channel](https://elixir-slackin.herokuapp.com) as well, though I don't frequent that myself, there are
many people who can answer questions there.

Failing that, feel free to open an issue on the tracker with questions, and I'll do my
best to get to it in a timely fashion!

## License

MIT. See the `LICENSE.md` in this repository for more details.
