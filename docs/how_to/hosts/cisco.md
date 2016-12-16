# Wind River Linux

Wind River Linux is an embedded systems OS from Wind, an Intel Company.  You
can get more details on this from their
[product page](http://www.windriver.com/products/linux/).

Beaker provides support for 2 of Cisco's Wind River Linux platforms.
Those platform codenames are `cisco_nexus` for Cisco NX-OS based systems
and `cisco_ios_xr` for Cisco IOS XR based systems.

Beaker currently can install puppet on Cisco Nexus and Cisco IOS XR.

# Host Requirements

WRLinux hosts validate their setup once created, and will fail if not
setup correctly.  There are two conditions that are validated specifically
on WRLinux hosts.  These conditions are listed below.

A. All Cisco Nexus hosts will need a `:vrf` value, which determines their
virtual routing framework for networking purposes.  For our purposes,
we tend to use the value `management`, so there is always a hosts
file line that looks like this in our configuration:

    HOSTS:
      <hostname>:
        ...
        vrf: management
    
B. All Cisco hosts will also require a user to be set on the
hosts.  This is because they don't allow ssh'ing as the root user,
which is one of the main assumptions that Beaker operates under in
the usual case.  In order to specify a user to ssh with, add this
block to a host:

    HOSTS:
      <hostname>:
        ...
        ssh:
          user: <username>

# Hypervisors

WRLinux has only been developed and tested as a
[vmpooler](https://github.com/puppetlabs/vmpooler) host.

This doesn't mean that it can't be used in another hypervisor, but that
Beaker doesn't specifically deal with the details of that hypervisor in creating
WRLinux hosts, if there is anything specific to WRLinux that will need to be done in
provisioning steps.

# Installation Methods

## Open Source

In order to install a puppet-agent against a WRLinux host, you'll have to use the
[`install_puppet_agent_on`](blob/master/lib/beaker/dsl/install_utils/foss_utils.rb#L327)
method.

It reaches out to the WRLinux-specific host code for any information that it needs.
You can check out [these methods](blob/master/lib/beaker/host/cisco.rb) if you
need more information about this.