# Overview

Distillery is a tool for packaging Elixir applications for deployment using 
OTP [releases](http://erlang.org/doc/design_principles/release_structure.html). In
a nutshell, Distillery produces an artifact, a tarball, which contains your application
and everything needed to run it. This artifact also contains scripts which allow you to run
the application in three different modes (console, foreground, and daemonized), as well as
a variety of utility commands, such as `remote_console` which provides an easy way to connect 
an IEx session to your running application. Releases are more than just a way to package your 
application though, and are a core part of Erlang's design, which we inherit in Elixir.

To begin, check out the [Up and Running](up_and_running.html) page.

If you ever feel that a topic is not well covered in these docs, or that content is out of date,
please open an issue [here](https://github.com/bitwalker/distillery).
