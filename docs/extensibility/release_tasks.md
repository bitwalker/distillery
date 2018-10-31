Once your release is built, you can execute a number of helpful commands from the entry script.

If you've built a release for `#!elixir :myapp`, you can run `bin/myapp` to see the full list of commands.

## Release tasks

| Task                | Description                                                                     |
|:--------------------|:--------------------------------------------------------------------------------|
| start               | Start myapp as a daemon                                                         |
| start_boot <file>   | Start myapp as a daemon, but supply a custom .boot file                         |
| foreground          | Start myapp in the foreground<br>This is similar to running `mix run --no-halt` |
| console             | Start myapp with a console attached<br>This is similar to running `iex -S mix`  |
| console_clean       | Start a console with code paths set but no apps loaded/started                  |
| console_boot <file> | Start myapp with a console attached, but supply a custom .boot file             |
| stop                | Stop the myapp daemon                                                           |
| restart             | Restart the myapp daemon without shutting down the VM                           |
| reboot              | Restart the myapp daemon                                                        |
| upgrade <version>   | Upgrade myapp to <version>                                                      |
| downgrade <version> | Downgrade myapp to <version>                                                    |
| attach              | Attach the current TTY to myapp's console                                       |
| remote_console      | Remote shell to myapp's console                                                 |
| reload_config       | Reload the current system's configuration from disk                             |
| pid                 | Get the pid of the running myapp instance                                       |
| ping                | Checks if myapp is running, pong is returned if successful                      |
| pingpeer <peer>     | Check if a peer node is running, pong is returned if successful                 |
| escript             | Execute an escript                                                              |
| rpc                 | Execute Elixir code on the running node                                         |
| eval                | Execute Elixir code locally                                                     |
| describe            | Print useful information about the myapp release                                |

## Running code in releases

Distillery comes with two very useful tasks for working with your release.

* Both will take some Elixir code and run it for you and show you the result.
* Both tasks use the exact same syntax, the only difference is the context your code is run in.

### Running code with `rpc`

This task executes code on the running node, and is what you'd want to use to interact with your application when _it's already running_.

!!! example "Using Module.fun/arity"
    ```bash tab="Command"
    $ ./bin/myapp rpc --mfa "Application.loaded_applications/0"
    ```

    ```elixir tab="Output"
    [
      {:lz_string,
       'Elixir implementation of pieroxy\'s lz-string compression algorithm.',
       '0.0.7'},
      {:phoenix_html,
      ...snip
    ```

??? example "Using Module.fun/arity with arguments"
    ```bash tab="Commands"
    $ ./bin/myapp rpc --mfa "Application.put_env/3" -- myapp token supersecret
    $ ./bin/myapp rpc --mfa "Application.get_env/2" -- myapp token
    ```

    ```bash tab="Output"
    $ ./bin/myapp rpc --mfa "Application.put_env/3" -- myapp token supersecret
    :ok
    $ ./bin/myapp rpc --mfa "Application.get_env/2" -- myapp token
    "supersecret"
    ```

??? example "Using Module.fun/1 with arguments as a single list"
    Here, the `--argv` option can be used to construct a list before passing your arguments to the function specified.

    ```bash tab="Command"
    $ ./bin/myapp rpc --mfa "Enum.join/1" --argv -- foo bar baz
    ```

    ```elixir tab="Output"
    "foobarbaz"
    ```

??? example "Using an expression, getting application version"
    You can also use an expression, but you'll need to be mindful of shell quoting.

    ```bash tab="Command"
    $ ./bin/myapp rpc 'Application.spec(:myapp, :vsn)'
    ```

    ```elixir tab="Output"
    '0.0.1'
    ```

??? example "Using an expression, broadcasting to a Phoenix channel"
    ```bash
    $ ./bin/myapp rpc 'MyappWeb.Endpoint.broadcast!("channel:lobby", "status", %{current_status: "oopsy"})'
    ```

### Running code with `eval`

This task executes code locally in a clean instance. Although execution will be within the context of your release, no applications will have been started. This is very useful for things like migrations, where you'll want to start only some applications (e.g. Ecto) manually before doing some work.

!!! example "Using Module.fun/arity"
    Assuming that you've created a `Myapp.ReleaseTasks` module, you can call it into like so:
    ```
    $ ./bin/myapp eval --mfa 'Myapp.ReleaseTasks.migrate/0'
    ```

??? example "Using Module.fun/arity with arguments"
    Like with `rpc`, arguments can be specified (but are generally treated as strings).

    ```bash
    $ ./bin/myapp eval --mfa 'File.touch/1' -- /tmp/foo
    :ok
    ```

??? example "Using an expression"
    Like with `rpc`, an expression can be used.

    ```bash tab="Command"
    $ ./bin/myapp eval 'Timex.Duration.now |> Timex.format_duration(:humanized)'
    ```

    ```elixir tab="Output"
    "48 years, 10 months, 2 weeks, 2 days, 4 hours, 8 minutes, 52 seconds, 883.16 milliseconds"
    ```
