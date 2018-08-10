# Hot upgrades and downgrades

## A word of caution

Hot upgrades are one of the most powerful capabilities of OTP, but with that
power comes a lot of associated complexity. Hot upgrades are so impressive
because of the technical feat required to swap out code at runtime, and while
OTP makes this process quite easy to accomplish, it also expects you to fully
understand what you are asking it to do. In other words, you need to be very
aware of how hot upgrades are performed, and how to manage change in your
applications such that you can perform upgrades seamlessly.

Distillery makes hot upgrades deceptively simple to use, because it
automatically generates appups for you (see [Appups](appups.md) for more).
This may lead you to believe that you can let Distillery handle this process
entirely for you, and you need to understand that this is not the case.
Distillery does this for you in order to make things easier on you, by only
requiring you to make small adjustments to the appups before building a release,
rather than having to write every appup from scratch. It is still on you to
review these generated appups, understand when they are correct, or when
something has been missed, or when you simply need to do your part in the
process (such as implementing `code_change` in processes you want upgraded).

Always remember though, that if an upgrade goes badly, you can always reboot
your application and get back to a good state, so if in doubt, just perform a
rolling release - only the most critical of applications will require hot
upgrades, and in those cases it will be worth your while to understand them in
great detail. I would recommend using rolling releases always, rather than
undertaking hot upgrades, but when you need them, they are there.

!!! warning
    It is not possible to use hot upgrades and `include_erts: false` in
    conjunction with one another. This is due to how `release_handler` manages
    information about releases as they are unpacked and installed. ERTS must be
    packaged in the release in order for hot upgrades/downgrades to properly
    work.

## Overview

!!! warning
    You *cannot* perform upgrades from within the `_build` directory -
    you must deploy the tarballs as described in the
    [Walkthrough](../introduction/walkthrough.md). Hot upgrades/downgrades
    mutate the release directory, and some of the files which are required for
    building releases will be missing if you do a build after upgrading a
    release there, resulting in errors when you attempt to upgrade/downgrade
    from that release. Always deploy to another local directory (for example,
    `/tmp`) first.

When building upgrade releases, Distillery will ensure that all modified
applications have appups generated for them. Appups are what tell `:systools`
how to generate the `relup` file, which contains low-level instructions for the
release handler, so that it knows how to load/remove/change modules in the
system during a hot upgrade.

Without an appup, an upgrade cannot succeed, because the release handler will
not know how to upgrade that application. Distillery takes great care to provide
good default instruction sets for the appups it generates, by ordering
instructions based on module dependencies, and whether things have been added,
removed, or modified; it makes sure to take advantage of special processes (such
as `GenServer` and friends) by using the `code_change` handler, and even handles
custom special processes started via `:proc_lib` by leveraging the
`system_code_change` handler.

However, while Distillery's appup generator is quite good, it can't be perfect
for all applications, or all situations. Any time you modify the internal state
of a process, say the state parameter of a `GenServer`, you will need to make
sure that the new version of the code knows how to transform the old state to
the new format, by implementing `code_change`, or what will happen is that the
new module will start executing using the old state, and things will blow up in
your face. It is important that you be aware of how your application has
changed, and ensure that you handle cases like these, either in your own code,
or by using instructions in the appup file Distillery generates (or even provide
your own).

When you upgrade from one release version to another, if something goes wrong
during the upgrade past the point of no return, the node will be restarted
running the original version of the code, and if something goes wrong early, the
changes will be rolled back. In both cases, the error will be printed to
standard output.

## Migrations

Since I have received many questions on this topic, I want to take a moment to
discuss hot upgrades in conjunction with migrations.

You need to consider migrations and application upgrades as two separate,
distinct deployments. Migrations should be backwards compatible with the old
version of the application, and should be deployed in advance of application
upgrades, so that you have a chance to vet, and roll back if necessary, the
migrated changes. Once the migration has been applied and confirmed to be good,
you then proceed with applying your application upgrade. If a problem with the
new application code occurs, you can then safely roll back the application
without needing to also roll back the migration (if even possible).

The above strategy does require that you have strict change management, so that
you incrementally apply changes, rather than try to do them all at once. This
has implications in your application code as well, since you need to usually
allow for two different code paths (one to support old schemas and one for new).
This seems onerous, but in practice it makes deployments easier to manage, and
changes can be introduced at a steady pace.

I say all of this because I see people wanting to have OTP apply migrations as
part of the hot upgrade process, but that is not what it was designed for, and
is not intended to make any guarantees about external systems - it only makes
guarantees about how it applies upgrades to application code. Trying to mix
these concerns together will only lead to pain, so avoid doing so at all cost!
