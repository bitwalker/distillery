# Using Distillery with systemd

**IMPORTANT:** You need to be aware that when running `bin/myapp upgrade <version>`, this command
will be executed in the _callers_ environment, not the environment defined by the systemd unit. If you
need environment variables to be available during the upgrade, then you need to either execute it with the
same environment as the systemd unit, or export those environment variables in the calling environment.

Here are three general approaches to running a Distillery release with Systemd:

#### 1. Run app as daemon using `start` and a `forking` Systemd service *with* pidfile

* Systemd can automatically restart your app if it crashes
* You'll need to generate a pidfile for your app. The [pid_file](https://github.com/OvermindDL1/pid_file) package makes this quite simple.
* Logs will be written to the `/logs` directory in your release

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
SyslogIdentifier=myapp
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```


#### 2. Run app as daemon using `start` and a `forking` Systemd service *without* pidfile

* Systemd will attempt (and probably fail) to guess your apps pid. Without the correct pid it will be unable to automatically restart your app if it crashes
* No need for pidfiles
* Logs will be written to the `/logs` directory in your release

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
Restart=on-failure
RestartSec=5
Environment=PORT=8080
Environment=LANG=en_US.UTF-8
SyslogIdentifier=myapp
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```


#### 3. Run app in `foreground` using a `simple` Systemd configuration

* Systemd can automatically restart your app if it crashes
* No need for pidfiles or pid-detection
* Logging is handled by systemd

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
ExecStop=/home/appuser/myapp/bin/myapp stop
Restart=on-failure
RestartSec=5
Environment=PORT=8080
Environment=LANG=en_US.UTF-8
SyslogIdentifier=myapp
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

Reportedly, if you get an error starting the service you may need to set `RemainAfterExit=yes`. While this may resove the issue it will prevent Systemd from restarting your app if it crashes.

For a more explanatory guide on using Distillery with systemd, see [here](http://mfeckie.github.io/Phoenix-In-Production-With-Systemd/) and foreground, see [here](https://elixirforum.com/t/distillery-node-is-not-running-and-non-zero-exit-code/3834)
