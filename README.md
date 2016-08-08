# Distillery

[![Master](https://travis-ci.org/bitwalker/distillery.svg?branch=master)](https://travis-ci.org/bitwalker/distillery)
[![Hex.pm Version](http://img.shields.io/hexpm/v/distillery.svg?style=flat)](https://hex.pm/packages/distillery)
[![Coverage Status](https://coveralls.io/repos/github/bitwalker/distillery/badge.svg?branch=master)](https://coveralls.io/github/bitwalker/distillery?branch=master)

Every alchemist requires good tools, and one of the greatest tools in the alchemist's disposal
is the distillery. The purpose of the distillery is to take something and break it down to it's
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
  [{:distillery, "~> 0.9"}]
end
```

Just add as a mix dependency and use `mix release`. This is a replacement for exrm, but is in beta at this time.

If you are new to releases, please review the [documentation](https://hexdocs.pm/distillery).

## TODO

- [x] Upgrades/downgrades
- [x] Plugin system from exrm
- [ ] Read-only filesystems
- [x] CLI tooling improvements
- [x] Documentation
- [x] Code cleanup

## License

MIT. See the `LICENSE.md` in this repository for more details.
