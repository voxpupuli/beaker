# EOS - Arista

EOS is the network device OS from Arista. You can get more details from their
[product page](https://www.arista.com/en/products/eos).

# Hypervisors

EOS has only been developed and tested as a
[vmpooler](https://github.com/puppetlabs/vmpooler) host.

This doesn't mean that it can't be used in another hypervisor, but that
Beaker doesn't specifically deal with the details of that hypervisor in creating
EOS hosts, if there is anything specific to EOS that will need to be done in
provisioning steps.

# Installation Methods

## Puppet Enterprise

`install_pe` should "just work".

## Open Source

In order to install a puppet-agent against an EOS host, you'll have to use the
[`install_puppet_agent_dev_repo_on`](blob/master/lib/beaker/dsl/install_utils/foss_utils.rb#L1085)
method.

It reaches out to the EOS-specific host code for any information that it needs.
You can check out [these methods](blob/master/lib/beaker/host/eos.rb) if you
need more information about this.