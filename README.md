# Bundler

So called because building releases involves "bundling" up the application and it's resources into
a single package for deployment.

This is a implementation of release building functionality for the Elixir standard library/tooling,
as a pluggable dependency. I'm using this to prototype the native implementation of this functionality
prior to merging into Elixir proper.

**WARNING: This package is an experimental replacement for exrm, use at your own risk!**

## Installation

```elixir
defp deps do
  [{:bundler, "~> 0.4"}]
end
```

Just add as a mix dependency and use `mix release`. This is a replacement for exrm, but is in beta at this time.

If you are new to releases, please review the [documentation](https://hexdocs.pm/bundler).

## TODO

- [x] Upgrades/downgrades
- [x] Plugin system from exrm
- [ ] Read-only filesystems
- [ ] CLI tooling improvements
- [ ] Documentation
- [ ] Code cleanup

## License

MIT. See the `LICENSE.md` in this repository for more details.
