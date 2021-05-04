Hosts/Nodes/SUTs are defined in the --hosts (--config) file in Yaml format. This file defines each node in the test configuration. The file can be saved anywhere and used with `beaker --hosts yourhost.yaml` (see [The Command Line](the_command_line.md) for more info).

Example hosts file:

```yaml
  HOSTS:
    ubuntu-1404-x64-master:
      roles:
        - master
        - agent
        - dashboard
        - database
      platform: ubuntu-1404-x86_64
      hypervisor: vagrant
      box: puppetlabs/ubuntu-14.04-64-nocm
      box_url: https://vagrantcloud.com/puppetlabs/boxes/ubuntu-14.04-64-nocm
      ip: 192.168.20.20
    ubuntu-1404-x64-agent:
      roles:
        - agent
      platform: ubuntu-1404-x86_64
      hypervisor: vagrant
      box: puppetlabs/ubuntu-14.04-64-nocm
      box_url: https://vagrantcloud.com/puppetlabs/boxes/ubuntu-14.04-64-nocm
      ip: 192.168.21.21
  CONFIG:
    nfs_server: none
    consoleport: 443
```

## Host Requirements

Hosts, or SUTs (Systems Under Test), must meet the following requirements:

* The SUT will need a properly configured network, hosts will need to be able to reach each other by hostname.
* On the SUT, you must configure passwordless SSH authentication for the root user.
* The SUT must have the `ntpdate` binary installed.
* The SUT must have the `curl` binary installed.
* On Windows, `Cygwin` must be installed (with `curl`, `sshd`, `bash`) and the necessary windows gems (`sys-admin`, `win32-dir`, etc).
* FOSS install: you must have `git`, `ruby`, and `rdoc` installed on your SUT.

## Required Host Settings

To properly define a host you must provide:

* name: The string identifying this host.
* platform: One of the Beaker supported platforms.

## Optional Host Settings

Additionally, Beaker supports the following host options:

* ip: The IP address of the SUT.
* hypervisor: One of `docker`, `solaris`, `ec2`, `vsphere`, `fusion`, `aix`, `vcloud` or `vagrant`.
  * Additional settings may be required depending on the selected hypervisor (ie, template, box, box_url, etc).  Check the documentation below for your hypervisor for details.
* snapshot: The name of the snapshot to revert to before testing.
* roles: The 'job' of this host, an array of `master`, `agent`, `frictionless`, `dashboard`, `database`, `default` or any user-defined string.
* pe_dir: The directory where PE builds are located, may be local directory or a URL.
* pe_ver: The version number of PE to install.
* vagrant_memsize: The memory size (in MB) for this host

## Supported Platforms

Beaker depends upon each host in the configuration file having a platform type that is correctly formatted and supported.  The platform is used to determine how various operations are carried out internally (such as installing packages using the correct package manager for the given operating system).

The platform's format is `/^OSFAMILY-VERSION-ARCH.*$/` where `OSFAMILY` is one of:

* fedora
* debian
* oracle
* scientific
* sles
* opensuse
* ubuntu
* windows
* solaris
* aix
* el (covers centos, redhat and enterprise linux)

`VERSION`'s format is not enforced, but should reflect the `OSFAMILY` selected (ie, ubuntu-1204-i386-master, scientific-6-i386-agent, etc).  `ARCH`'s format is also not enforced, but should be appropriate to the `OSFAMILY` selected (ie, ubuntu-1204-i386-master, sles-11-x86_64-master, debian-7-amd64-master, etc).

## [Supported Virtualization Providers](../how_to/hypervisors/README.md#external-hypervisors)
