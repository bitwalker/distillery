# Running migrations

A very common task as part of deployment is the ability to run migrations, or other
automated prep work prior to starting the new version. There are a number of approaches
I've seen people take using the primitives Distillery provides, however my favored approach
is one that I have not seen people use yet, and it surprises me because it is so easy and feels
much more comfortable to use.

The approach is the following:

  * Define a module which will execute the migrations, this is a common
    requirement of all approaches to running migrations in a release.
  * Define a custom command which will execute this module for you without
    requiring that you type the module, function, and arguments yourself.

## Migration module

The following code is an example of a module which will run your Ecto migrations:

```elixir
defmodule MyApp.ReleaseTasks do
  @start_apps [
    :crypto,
    :ssl,
    :postgrex,
    :ecto,
    :ecto_sql # If using Ecto 3.0 or higher
  ]

  @repos Application.get_env(:my_app, :ecto_repos, [])

  def migrate(_argv) do
    start_services()

    run_migrations()

    stop_services()
  end

  def seed(_argv) do
    start_services()

    run_migrations()

    run_seeds()

    stop_services()
  end

  defp start_services do
    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for app
    IO.puts("Starting repos..")
    
    # pool_size can be 1 for ecto < 3.0
    Enum.each(@repos, & &1.start_link(pool_size: 2))
  end

  defp stop_services do
    IO.puts("Success!")
    :init.stop()
  end

  defp run_migrations do
    Enum.each(@repos, &run_migrations_for/1)
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config(), :otp_app)
    IO.puts("Running migrations for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  defp run_seeds do
    Enum.each(@repos, &run_seeds_for/1)
  end

  defp run_seeds_for(repo) do
    # Run the seed script if it exists
    seed_script = priv_path_for(repo, "seeds.exs")

    if File.exists?(seed_script) do
      IO.puts("Running seed script..")
      Code.eval_file(seed_script)
    end
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config(), :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end
end
```

!!! warning
    Remember to put this file under `lib`, as it must be compiled with the rest of your application, otherwise the code will not be available in the release, and the migrate command will fail.

## Custom command

Create the following shell scripts at `rel/commands/`:

* `rel/commands/migrate.sh`

```bash
#!/bin/sh

release_ctl eval --mfa "MyApp.ReleaseTasks.migrate/1" --argv -- "$@"
```

* `rel/commands/seed.sh`

```bash
#!/bin/sh

release_ctl eval --mfa "MyApp.ReleaseTasks.seed/1" --argv -- "$@"
```

For more info on the shell API look at the [Shell Scripts](../extensibility/shell_scripts.md) document.

## Tying it all together

Now that we have our custom command and migrator module defined, we just need to set up our config appropriately in the `rel/config.exs` file:

```elixir
...

release :myapp do
  ...
  set commands: [
    migrate: "rel/commands/migrate.sh",
    seed: "rel/commands/seed.sh",
  ]
end

...
```

Now, once you've deployed your application, you can run migrations/seeds with
`bin/myapp migrate` and `bin/myapp seed`.

## Thoughts

There are other approaches that may make more sense for your use case, for example, automatically running migrations
by defining a pre-start hook which does basically the same thing as above, just in a hook instead of a command. You can
even define the command, and execute the command as part of the hook, giving you the flexibility of both approaches.

Custom commands give you a lot of power to express potentially complex operations as a terse statement. I would encourage
you to use them for these types of tasks rather than using the raw `rpc` and `eval` tasks!
