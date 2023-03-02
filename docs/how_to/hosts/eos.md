# EOS - Arista

EOS is the network device OS from Arista. You can get more details from their [product page](https://www.arista.com/en/products/eos).

It reaches out to the EOS-specific host code for any information that it needs. You can check out [these methods](blob/master/lib/beaker/host/eos.rb) if you need more information about this.

# Hypervisors

EOS has only been developed and tested as a [vmpooler](https://github.com/puppetlabs/vmpooler) host.

This doesn't mean that it can't be used in another hypervisor, but that Beaker doesn't specifically deal with the details of that hypervisor in creating EOS hosts, if there is anything specific to EOS that will need to be done in provisioning steps.
