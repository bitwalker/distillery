# Umbrella Projects

Historically, `exrm` had poor support for umbrella projects. It worked by building a release
of each application individually, which in some cases was a fit, and in others, was not at
all the desired result. Distillery has been written with both standard and umbrella projects
in mind, and particularly with the goal of flexible handling of umbrella projects.

If you run `mix release.init` in a umbrella project, it will template out a configuration file
which bundles all of the applications in the umbrella under a single release. If you would prefer
`exrm`'s behaviour of a release per application in the umbrella, run `mix release.init --release-per-app`.

You may also define whatever combination of apps to releases you wish. Let's say you have an umbrella
with apps `lib_a`, `lib_b` `app_c`, `app_d`, and `app_e`, you could define any combination of `app_c`,
`app_d`, and `app_e` you want, and their dependencies to `lib_a` and `lib_b` will be automatically
resolved to pull them in as needed. For instance, maybe you want to release `app_c` and `app_d` together,
but release `app_e`  separately - this would look like the following in `rel/config.exs`:

```elixir
release :app_c_and_d do
  set version: "0.1.0"
  set applications: [:app_c, :app_d]
end

release :app_e do
  set version: current_version(:app_e)
end
```

As you can see, you have a lot of flexibility in how you handle releases with umbrella projects!
