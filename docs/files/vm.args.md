# vm.args

The `vm.args` file is how one provides configuration for the Erlang VM itself. You can
also use it to configure applications, but it is generally recommended to use `config.exs`
or `sys.config` for that instead.

Distillery will generate a default `vm.args` file for you, which configures the VM for distribution,
as shown below:

```
## Name of the node
-name <%= release_name %>@127.0.0.1

## Cookie for distributed erlang
-setcookie <%= release.profile.cookie %>

## Heartbeat management; auto-restarts VM if it dies or becomes unresponsive
## (Disabled by default..use with caution!)
##-heart

## Enable kernel poll and a few async threads
##+K true
##+A 5

## Increase number of concurrent ports/sockets
##-env ERL_MAX_PORTS 4096

## Tweak GC to run more often
##-env ERL_FULLSWEEP_AFTER 10

# Enable SMP automatically based on availability
-smp auto
```

This is templated via EEx, so that we can dynamically set the name and cookie based on configuration.

## Custom Args

You can easily provide your own `vm.args` file, either for
the release as a whole, or for a specific environment, via the `vm_args: "path/to/file"` option
in `rel/config.exs`. For example, perhaps you want to generate a `vm.args` which dynamically fetches
the secret cookie or hostname from the environment, but uses the configured release name for the node
name. You can do that like so:


```
## Node name
-name <%= release_name %>@${HOSTNAME}

## Node cookie, used for distribution
-setcookie ${NODE_COOKIE}
```

This will again be templated via EEx, so that `release_name` is replaced with the name of the release,
and you can provide additional variables beyond the defaults via the `:overlay_vars` option in `rel/config.exs`.

The `${HOSTNAME}` and `${NODE_COOKIE}` parts will only be dynamically replaced at runtime if you export
`REPLACE_OS_VARS=true` in the system environment prior to starting the release, so be sure you do so if you
want to use this approach.

For more information on `vm.args`, please see the documentation on [erl](http://erlang.org/doc/man/erl.html),
specifically the Flags section.

