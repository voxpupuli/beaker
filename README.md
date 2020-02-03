# Beaker

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

# License

See [LICENSE](LICENSE) file.

# Support & Issues

Please log tickets and issues at our [Beaker Issue Tracker](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR). In addition there is an active #puppet-dev channel on Freenode.

For additional information on filing tickets, please check out our [CONTRIBUTOR doc](CONTRIBUTING.md), and for ticket lifecycle information, check out our [ticket process doc](docs/concepts/ticket_process.md).

# Contributing

If you'd like to contribute improvements to Beaker, please see [CONTRIBUTING](CONTRIBUTING.md).

# Maintainers

For information on project maintainers, please check out our [CODEOWNERS doc](CODEOWNERS).

# Releasing

Since the beaker project has always been the central hub for all beaker testing, its release process has been more involved than most beaker-libraries (ie. [beaker-puppet](https://github.com/puppetlabs/beaker-puppet)).
Historically, the process has been described in [Confluence: Beaker Release Process](https://confluence.puppetlabs.com/display/SRE/Beaker+Release+Process) (apologies, most links in this section are Puppet-internal).

To release new versions of beaker, please use this [jenkins job](https://jenkins-sre.delivery.puppetlabs.net/view/all/job/qe_beaker-gem_init-multijob_master/). This job lives on internal infrastructure.

To run the job, click on `Build with Parameters` in the menu on the left. Make sure you verify the checkbox next to `PUBLIC` is checked and enter the appropriate version. The version should adhere to semantic version standards. When in doubt, consult [the maintainers of Beaker](#maintainers) for guidance.
