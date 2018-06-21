# Change Log

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](http://keepachangelog.com)
& makes a strong effort to adhere to
[Semantic Versioning](http://semver.org).

Tracking in this Changelog began for this project in version 3.25.0.
If you're looking for changes from before this, refer to the project's
git logs & PR history.

# [Unreleased](https://github.com/puppetlabs/beaker/compare/3.36.0...master)

### Fixed

- Exit early on --help/--version/--parse-only arguments instead of partial dry-run

### Added

- `Beaker::Shared::FogFileParser.parse_fog_file()` to parse .fog credential files

# [3.36.0](https://github.com/puppetlabs/beaker/compare/3.35.0...3.36.0) - 2018-06-18

### Fixed

- Raise `ArgumentError` when passing `role = nil` to `only_host_with_role()` or `find_at_most_one_host_with_role()`
- Use `install_package_with_rpm` in `add_el_extras`

### Added

- Installation instructions for contributors
- Markdown formatting guidelines for `docs/`
- Glossary for project jargon in [`docs/concepts/glossary.md`](docs/concepts/glossary.md)
- Use AIX 6.1 packages everywhere for puppet6

# [3.35.0](https://github.com/puppetlabs/beaker/compare/3.34.0...3.35.0) - 2018-05-16

### Fixed

- Report accurate location of generated smoke test
- Accept comma-separated tests for exec subcommand

### Added

- Added optional ability to use ERB in nodeset YAML files

# [3.34.0](https://github.com/puppetlabs/beaker/compare/3.33.0...3.34.0) - 2018-03-26

### Fixed

- Recursively glob the tests directory

### Added

- Codename for Ubuntu 18.04 'Bionic'

# [3.33.0](https://github.com/puppetlabs/beaker/compare/3.32.0...3.33.0) - 2018-03-07

### Changed

- Use relative paths for beaker exec

# [3.32.0](https://github.com/puppetlabs/beaker/compare/3.31.0...3.32.0) - 2018-02-22

### Changed

- Fully qualify sles ssh restart cmd
- Deprecated deploy_package_repo methods
- Configuration of host type in host_prebuilt_steps

### Added

- Added missing beaker options for subcommand passthorugh

# [3.31.0](https://github.com/puppetlabs/beaker/compare/3.30.0...3.31.0) - 2018-01-22

### Changed

- Clean up ssh paranoid setting deprecation warnings

### Added

- Add macOS 10.13 support

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

