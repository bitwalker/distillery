# Distillery

[![Master](https://travis-ci.org/bitwalker/distillery.svg?branch=master)](https://travis-ci.org/bitwalker/distillery)
[![Hex.pm Version](http://img.shields.io/hexpm/v/distillery.svg?style=flat)](https://hex.pm/packages/distillery)

  * [Documentation](https://hexdocs.pm/distillery)
  * [CHANGELOG](https://hexdocs.pm/distillery/changelog.html)
  * [Upgrading to 2.x](https://hexdocs.pm/distillery/upgrading_to_2_0.html)

## About

Every alchemist requires good tools, and one of the greatest tools in the alchemist's disposal
is the distillery. The purpose of the distillery is to take something and break it down to its
component parts, reassembling it into something better, more powerful. That is exactly
what this project does - it takes your Mix project and produces an Erlang/OTP release, a
distilled form of your raw application's components; a single package which can be deployed anywhere,
independently of an Erlang/Elixir installation. No dependencies, no hassle.

This is a pure-Elixir, dependency-free implementation of release generation for Elixir projects.
It is currently a standalone package, but may be integrated into Mix at some point in the future.

## Installation

Distillery requires Elixir 1.6 or greater. It works with Erlang 20+.

```elixir
defp deps do
  [{:distillery, "~> 2.1"}]
end
```

Just add as a mix dependency and use `mix distillery.release`.

If you are new to releases or Distillery, please review the [documentation](https://hexdocs.pm/distillery),
it is extensive and covers just about any question you may have!

## Community/Questions/etc.

If you have questions or want to discuss Distillery, releases, or other deployment
related topics, a good starting point is the Deployment section of ElixirForum, which
can be found [here](https://elixirforum.com/c/dedicated-sections/deployment).

I can often be found in IRC on freenode, in the `#elixir-lang` channel, and there is
also an [Elixir Slack channel](https://elixir-slackin.herokuapp.com) as well, though I don't frequent that myself, there are
many people who can answer questions there.

Failing that, feel free to open an issue on the tracker with questions, and I'll do my
best to get to it in a timely fashion!

## License

MIT. See the [`LICENSE.md`](https://github.com/bitwalker/distillery/blob/master/LICENSE.md) in this repository for more details.
