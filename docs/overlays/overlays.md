# Overlays

Overlays allow you to modify the contents of the release, you may add/symlink files, create directories,
and generate files based on templates.

You may add overlays via your release configuration, e.g:

```elixir
release :myapp do
  ..snip..
  set overlays: [
    {:mkdir, "configs"},
    {:template, "priv/templates/myconfig.eex", "configs/<%= release_name %>.config"}
  ]
end
```

Overlay paths are templated via EEx, with the contents of Distillery-provided overlay vars, including
those you provide via the `overlay_vars` setting. The `template` overlay type assumes the source file is
an EEx template, and generates it using the same overlay vars mentioned above, then copies it to the destination
path provided.

All source paths (i.e. those in `copy`, `link`, and `template` overlays) are relative to the project root. All
destination paths (`mkdir` is just a destination path) are relative to the release output directory, which will
be `rel/<release_name>`.

Currently, the following overlay vars are provided out of the box by Distillery:

```markdown
  - release_name: Name of the release being built
  - release_version: Version of the release being built
  - is_upgrade: Is this release an upgrade release
  - upgrade_from: The version of the release being upgraded from, nil if not an upgrade.
  - dev_mode: Is this release being built in dev mode
  - include_erts: Is ERTS being included in the release
  - include_src: Is source code being included in the release
  - include_system_libs: Are system libraries being included in the release
  - erl_opts: The string of options which will be passed to `erl` when running the release
  - run_erl_env: The string of environment variable assignments which will be applied to `run_erl` when running the release
  - erts_vsn: The current ERTS version
  - output_dir: The release output directory
```

You may add your own to this list by setting `overlay_vars` to a keyword list of names to values you wish
to make available to templates.
