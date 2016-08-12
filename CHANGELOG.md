## 0.9.3

### Fixed

- Fixed start types not being honored when resolving apps
- Fixed dependencies missing from applications list not
  being added to the release. They are now added with a
  start type of :load.
- Fixed src directory being added to release when include_src is false
- Fixed hidden files in apps directory of umbrellas causing an exception
