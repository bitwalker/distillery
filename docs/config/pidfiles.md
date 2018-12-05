# PID files

Distillery now has the ability to create a PID file during boot. A PID file is a
file which contains the PID of the executable which generated it. When an
application terminates, that file is removed. If it is removed while the
application is running, the application terminates. If the application restarts,
a new PID is written to the file.

These files are used in particular by system supervisors, such as systemd, to
better monitor and interact with the services under their purvey. In general I
recommend using foreground mode when running under systemd, but if you prefer to
run the service as a daemon via start, and have systemd monitor that, PID file
support provides better integration than previous releases.

!!! tip
    If you are looking into this because you are using `systemd`, I would
    encourage you to instead define a service unit which leverages the `foreground`
    task, rather than `start`. Not only do you not need a PID file in this case,
    but you get automatic log management via syslog/journalctl. This feature was
    added because that isn't always an option, but if you have the choice, the
    above is a simpler approach.

## Usage

To turn on PID file generation, you have two choices:

  * Export an environment variable, `PIDFILE="path/to/pidfile"`
  * Set a flag in `vm.args`, `-kernel pidfile '"path/to/pidfile"'`

!!! warning
    We need to use two level of quoting, due to how erl parses the command line arguments

!!! info
    We use the `kernel` application for this setting because the PID file
    manager process is started as a kernel process, so to access the
    configuration, it must be part of the `kernel` application.

If either of these are set, when the PID file manager is started, it will write
the current PID to the given path, and then monitor it for changes. If it
detects that the file has been deleted, then the node is terminated. If asked to
terminate, it will clean up the PID file before doing so.

!!! warning
    If you terminate a node brutally, the PID file will remain, since
    our process will never have a chance to execute any cleanup in that case - but
    shutting down that way is not recommended for a variety of reasons, one of which
    is the likelihood of resources being left hanging in the wind. If the PID file
    still exists when the release is restarted, it will be overwritten with the new
    PID, but it may cause some confusion for external processes like systemd.
