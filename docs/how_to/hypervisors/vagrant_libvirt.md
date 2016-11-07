# Vagrant Libvirt #

This driver enabled a tester to trigger tests using libvirtd daemon.
It is based
on [libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt)'s
plugin for vagrant.

## Basic Options ##

Once you've setup the libvirt daemon on your beaker coordinator, you
can use the vagrant_libvirt hypervisor by providing beaker with a
configuration similar to this:

```yaml
HOSTS
  centos-puppet-keystone:
    hostname: puppet-keystone.example.net
    roles:
      - master
    platform: el-7-x86_64
    box: centos/7
    box_url:  http://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7.LibVirt.box
    hypervisor: vagrant_libvirt
    vagrant_memsize: 4096
    vagrant_cpus: 2
```

Those are the usual beaker parameters. Note the `hypervisor`
parameter. Multiple VMs is supported.


## Advanced Options and remote libvirt daemon ##

This driver gives the tester access to all available parameters from
the vagrant-libvirt plugin. Beware there could be dragons here as
beaker has some expectations about the created VMs.

To pass them down the operator adds them in the config section, here
is a example.

```yaml
CONFIG:
  libvirt:
    uri: qemu+ssh://root@libvirt.system.com/system
```

The `uri` parameter is one of the most useful. The user can have its
test done on a remote libvirt daemon. The network setup between the
VMs and the host running beaker will have to be done manually though.
`management_network_name` and `management_network_address` parameters
can be useful here.

Another good cadidate is `volume_cache: unsafe`.

A complete list of options is available in
the
[vagrant plugin](https://github.com/vagrant-libvirt/vagrant-libvirt)
repository.
