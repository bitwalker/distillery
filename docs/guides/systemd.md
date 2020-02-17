# Using Distillery with systemd

!!! warning
    You need to be aware that when running `bin/myapp upgrade <version>`,
    this command will be executed in the *callers* environment, not
    the environment defined by the systemd unit. If you need environment
    variables to be available during the upgrade, then you need to either
    execute it with the same environment as the systemd unit, or export those
    environment variables in the calling environment.

Here are two general approaches to running a Distillery release with systemd:

## Run app as daemon using `start` and a `forking` Systemd service *with* pidfile

Properties of this approach:

  * Your app will be automatically restarted if it crashes
  * Logs will be written to the `var/log` directory in your release
  * If your app is killed suddenly (on Linux this would mean receiving a `SIGKILL`,as used by "OOM Killer") then your app may not get a chance to remove the pidfile and so it may not be restarted. If this is a concern kill your app with `pkill -9 beam.smp` and ensure that the pifile is removed and that the systemd detects strats it again.

```systemd
[Unit]
Description=My App
After=network.target

[Service]
Type=forking
User=appuser
Group=appuser
WorkingDirectory=/home/appuser/myapp
ExecStart=/home/appuser/myapp/bin/myapp start
ExecStop=/home/appuser/myapp/bin/myapp stop
PIDFile=/home/appuser/myapp/myapp.pid
Restart=on-failure
RestartSec=5
Environment=PORT=8080
Environment=LANG=en_US.UTF-8
Environment=PIDFILE=/home/appuser/myapp/myapp.pid
SyslogIdentifier=myapp
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

## Run app in `foreground` using a `simple` systemd configuration

Properties of this approach:

  * Your app will be automatically restarted if it crashes
  * Logging is handled by systemd, which makes for better integration with log
    aggregation tools
  * It is a less cumbersome setup (does not require any pidfile and associated detection)

```systemd
[Unit]
Description=My App
After=network.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/home/appuser/myapp
ExecStart=/home/appuser/myapp/bin/myapp foreground
Restart=on-failure
RestartSec=5
Environment=PORT=8080
Environment=LANG=en_US.UTF-8
SyslogIdentifier=myapp
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

!!! tip
    We have heard that in some cases, if an error occurs when starting the
    service, you may need to set `RemainAfterExit=yes`. This will disable
    automatic restart in the case of failure though, so you should avoid doing
    this unless it is your only option (or desired behavior)
    
If you'd like your app to start automatically when the server starts (useful in case the server is rebooted). You'll need to run `systemctl enable myapp.service`.

For more information about Distillery and systemd, the following links may be useful (though possibly outdated):

  * [Phoenix In Production With systemd](http://mfeckie.github.io/Phoenix-In-Production-With-Systemd/)
  * [ElixirForum - Distillery node is not running and non-zero exit code](https://elixirforum.com/t/distillery-node-is-not-running-and-non-zero-exit-code/3834)
