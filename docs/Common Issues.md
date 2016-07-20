# Common Issues

## Upgrade failures

If you see the following error when upgrading:

```
ERROR: release_handler:check_install_release failed: {'EXIT',
                                                      {{badmatch,
                                                        {error,beam_lib,
                                                         {missing_chunk,
                                                          ...}]
```

Then the currently installed version had it's debug information stripped, via
`strip_debug_info: true` in the release configuration. Distillery will print
a warning when you build an upgrade with that setting set to `true`, because
this is what happens when you try to upgrade a release which has had it's BEAMs
stripped. To fix this, you will need to stop the currently running release, and extract
the tarball over the top of the release root directory, then start the release again.
To prevent this from happening in the future, set `strip_debug_info: false` when using
hot upgrades.
