# Using Distillery with System D

The following is an example systemd unit file for a Distillery release:

		[Unit]
		Description=My App
		After=network.target

		[Service]
		Type=simple
		User=appuser
		Group=appuser
		WorkingDirectory=/home/appuser/myapp
		ExecStart=/home/appuser/myapp/bin/myapp start
		ExecStop=/home/appuser/myapp/bin/myapp stop
		Restart=on-failure
		RemainAfterExit=yes
		RestartSec=5
		Environment=PORT=8080
		Environment=LANG=en_US.UTF-8
		SyslogIdentifier=myapp

		[Install]
		WantedBy=multi-user.target

It's important that you have `RemainAfterExit=yes` set, or you will get an error trying to start
the service.

For a more explanatory guide on using Distillery with systemd, see [here](http://mfeckie.github.io/Phoenix-In-Production-With-Systemd/)
