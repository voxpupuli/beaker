# Beaker

[![License](https://img.shields.io/github/license/voxpupuli/beaker.svg)](https://github.com/voxpupuli/beaker/blob/master/LICENSE)
[![Test](https://github.com/voxpupuli/beaker/actions/workflows/test.yml/badge.svg)](https://github.com/voxpupuli/beaker/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/voxpupuli/beaker/branch/master/graph/badge.svg?token=Mypkl78hvK)](https://codecov.io/gh/voxpupuli/beaker)
[![Release](https://github.com/voxpupuli/beaker/actions/workflows/release.yml/badge.svg)](https://github.com/voxpupuli/beaker/actions/workflows/release.yml)
[![RubyGem Version](https://img.shields.io/gem/v/beaker.svg)](https://rubygems.org/gems/beaker)
[![RubyGem Downloads](https://img.shields.io/gem/dt/beaker.svg)](https://rubygems.org/gems/beaker)
[![Donated by Puppet Inc](https://img.shields.io/badge/donated%20by-Puppet%20Inc-fb7047.svg)](#transfer-notice)

Beaker is a test harness focused on acceptance testing via interactions between multiple (virtual) machines. It provides platform abstraction between different Systems Under Test (SUTs), and it can also be used as a virtual machine provisioner - setting up machines, running any commands on those machines, and then exiting.

Beaker runs tests written in Ruby, and provides additional Domain-Specific Language (DSL) methods.  This gives you access to all standard Ruby along with acceptance testing specific commands.

# Installation

See [Beaker Installation](docs/tutorials/installation.md).

# Documentation

Documentation for Beaker can be found in this repository in
[the docs/ folder](docs/README.md).

## Table of Contents

- [Tutorials](docs/tutorials) take you by the hand through the steps to setup a beaker run. Start here if you’re new to Beaker or test development.
- [Concepts](docs/concepts) discuss key topics and concepts at a fairly high level and provide useful background information and explanation.
- [Rubydocs](http://rubydoc.info/github/puppetlabs/beaker/frames) contains the technical reference for APIs and other aspects of Beaker. They describe how it works and how to use it but assume that you have a basic understanding of key concepts.
- [How-to guides](docs/how_to) are recipes. They guide you through the steps involved in addressing key problems and use-cases. They are more advanced than tutorials and assume some knowledge of how Beaker works.

# Beaker Libraries

Beaker functionality has been extended through the use of libraries available as gems. See the [complete list](docs/concepts/beaker_libraries.md) for available gems. See the [beaker-template documentation](https://github.com/puppetlabs/beaker-template/blob/master/README.md) for documentation on creating beaker-libraries.

# Support & Issues

Please log tickets and issues at our [Beaker Issue Tracker](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR). In addition there is an active #puppet-dev channel on Freenode.

For additional information on filing tickets, please check out our [CONTRIBUTOR doc](CONTRIBUTING.md), and for ticket lifecycle information, check out our [ticket process doc](docs/concepts/ticket_process.md).

# Contributing

If you'd like to contribute improvements to Beaker, please see [CONTRIBUTING](CONTRIBUTING.md).

# Maintainers

For information on project maintainers, please check out our [CODEOWNERS doc](CODEOWNERS).

## Transfer Notice

This plugin was originally authored by [Puppet Inc](http://puppet.com).
The maintainer preferred that Puppet Community take ownership of the module for future improvement and maintenance.
Existing pull requests and issues were transferred over, please fork and continue to contribute here.

Previously: https://github.com/puppetlabs/beaker

## License

This gem is licensed under the Apache-2 license.

## Release information

To make a new release, please do:
* update the version in the gemspec file
* Install gems with `bundle install --with release --path .vendor`
* generate the changelog with `bundle exec rake changelog`
* Check if the new version matches the closed issues/PRs in the changelog
* Create a PR with it
* After it got merged, push a tag. GitHub actions will do the actual release to rubygems and GitHub Packages
