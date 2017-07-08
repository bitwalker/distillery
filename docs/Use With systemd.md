# Using Distillery with systemd

The following is an example systemd unit file for a Distillery release:

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
		RemainAfterExit=yes

		[Install]
		WantedBy=multi-user.target

It's important that you have `RemainAfterExit=yes` set, or you will get an error trying to start
the service.

The following is an example systemd unit file for a Distillery release using foreground:

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
                KillMode=process
                SuccessExitStatus=143
                TimeoutSec=10
                RestartSec=5
                Environment=PORT=8080
                Environment=LANG=en_US.UTF-8
                SyslogIdentifier=myapp

                [Install]
                WantedBy=multi-user.target

For a more explanatory guide on using Distillery with systemd, see [here](http://mfeckie.github.io/Phoenix-In-Production-With-Systemd/) and foreground, see [here](https://elixirforum.com/t/distillery-node-is-not-running-and-non-zero-exit-code/3834)
