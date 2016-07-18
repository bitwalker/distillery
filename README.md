# Distillery

To distill something means to draw out the important components of something and recombine
them into an improved form. That is what `distillery` does; it takes your Mix project and
produces an Erlang/OTP release, a distilled form of your raw application, a single package
which can be deployed anywhere, independently of a separate Erlang/Elixir installation.

Plus, what can I say, I like the imagery of distillation/elixir/alchemy.

This is a pure-Elixir, dependency-free implementation of release generation for Elixir projects.
It is currently a standalone package, but may be integrated into Mix at some point in the future.

**WARNING: This package is an experimental replacement for exrm, use at your own risk!**

## Installation

Distillery requires Elixir 1.3 or greater.

```elixir
defp deps do
  [{:distillery, "~> 0.6"}]
end
```

Just add as a mix dependency and use `mix release`. This is a replacement for exrm, but is in beta at this time.

If you are new to releases, please review the [documentation](https://hexdocs.pm/distillery).

## TODO

- [x] Upgrades/downgrades
- [x] Plugin system from exrm
- [ ] Read-only filesystems
- [ ] CLI tooling improvements
- [ ] Documentation
- [ ] Code cleanup

## License

MIT. See the `LICENSE.md` in this repository for more details.
