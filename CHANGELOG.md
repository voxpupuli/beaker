# Change Log

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](http://keepachangelog.com)
& makes a strong effort to adhere to
[Semantic Versioning](http://semver.org).

Tracking in this Changelog began for this project in version 3.25.0.
If you're looking for changes from before this, refer to the project's
git logs & PR history.

# [Unreleased](https://github.com/puppetlabs/beaker/compare/3.30.0...master)

# [3.30.0](https://github.com/puppetlabs/beaker/compare/3.29.0...3.30.0) - 2018-01-10

### Changed

- Use `host.hostname` when combining options host_hash with host instance options

### Removed

- `amazon` as a platform value

### Added

- Load project options from .beaker.yml

# [3.29.0](https://github.com/puppetlabs/beaker/compare/3.28.0...3.29.0) - 2017-11-16

### Added

- Adding default to read fog credentials

# [3.28.0](https://github.com/puppetlabs/beaker/compare/3.27.0...3.28.0) - 2017-11-01

### Fixed

- corruption of `opts[:ignore]` when using `rsync`

# [3.27.0](https://github.com/puppetlabs/beaker/compare/3.26.0...3.27.0) - 2017-10-19

### Added

- support amazon as a platform
- add codenames for MacOS 10.13 and Ubuntu Artful

# [3.26.0](https://github.com/puppetlabs/beaker/compare/3.25.0...3.26.0) - 2017-10-05

### Added

- concept of `manual_test` and `manual_step`

# [3.25.0](https://github.com/puppetlabs/beaker/compare/3.24.0...3.25.0) - 2017-09-26

