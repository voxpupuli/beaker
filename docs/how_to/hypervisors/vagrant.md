# Vagrant

Vagrant's slogan is "development environments made easy". They provide an
abstraction on top of a VM or cloud provider that allows you to manage
hosts and their provisioning. [Their Site](https://www.vagrantup.com/).

# Getting Started

### Requirements

A prerequisite for using the vagrant hypervisor with beaker is that the
**Vagrant 1.7+** package needs to installed - 
see [downloads.vagrantup.com](http://downloads.vagrantup.com/) for downloads.

Currently, we provide a suite of pre-built, publicly available vagrant boxes for
use in constructing tests: [Puppet Labs Vagrant Boxes](https://vagrantcloud.com/puppetlabs/).
You can use these boxes easily by pulling one of our
[Example Vagrant Hosts Files](vagrant_hosts_file_examples.md).

### Setup a Vagrant Hosts File

A vm is identified by `box` or `box_url` in the config file.  No snapshot name
is required as the vm is reverted back to original state post testing using
`vagrant destroy --force`.

**Example Vagrant hosts file**

    HOSTS:
      ubuntu-1404-x64:
        roles:
          - master
          - agent
          - dashboard
          - cloudpro
        platform: ubuntu-1404-x86_64
        hypervisor: vagrant
        box: puppetlabs/ubuntu-14.04-64-nocm
        box_url: https://vagrantcloud.com/puppetlabs/boxes/ubuntu-14.04-64-nocm
    CONFIG:
      nfs_server: none
      consoleport: 443

VagrantFiles are created per host configuration file.  They can be found in the
`.vagrant/beaker_vagrant_files` directory of the current working directory in a
subdirectory named after the host configuration file.

    > beaker --hosts sample.cfg
    > cd .vagrant/beaker_vagrant_files; ls
    sample.cfg
    > cd sample.c

Below are details of vagrants features as they're supported through beaker. If
you'd like to see more examples of vagrant hosts files, checkout our
[vagrant hosts file examples doc](vagrant_hosts_file_examples.md).

# Vagrant-Specific Hosts File Settings

### Running With a GUI

It is possible to have the VirtualBox VM run with a GUI (i.e. non-headless mode)
by specifying ``vb_gui`` of any non-nil value in the config file, i.e.:

**Example Vagrant hosts file with vb_gui**

    HOSTS:
      ubuntu-1404-x64:
        roles:
          - master
          - agent
          - dashboard
          - cloudpro
        platform: ubuntu-1404-x86_64
        hypervisor: vagrant
        box: puppetlabs/ubuntu-14.04-64-nocm
        box_url: https://vagrantcloud.com/puppetlabs/boxes/ubuntu-14.04-64-nocm
        vb_gui: true
    CONFIG:
      nfs_server: none
      consoleport: 443

### Mounting Local Folders

When using the Vagrant Hypervisor, beaker can mount specific local directories
as synced_folders inside the vagrant box. This is done by using the
`mount_folders` option in the nodeset file.

**Example hosts file**

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
        mount_folders:
          folder1:
            from: ./
            to: /vagrant/folder1
          tmp:
            from: /tmp
            to: /vagrant/tmp
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

In the above beaker will mount the folders `./` to `/vagrant/folder1` and the
folder `/tmp` to `/vagrant/tmp`.

### Forwarding Ports to Guest

When using the Vagrant Hypervisor, beaker can create the Vagrantfile to forward specified ports to a specific box. This is done by using the `forwarded_ports` option in the nodeset file.

**Example hosts file**

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
        forwarded_ports:
          apache:
            from: 10080
            to: 80
          tomcat:
            from: 8080
            to: 8080
            from_ip: '127.0.0.1'
            to_ip: '0.0.0.0'

In the above, beaker will forward port 10080 and 8080 on the Host to port 80 and 8080 (respectively) on the Agent guest.

# vagrant plugins #

You can check more information for some suported vagrant plugins:

 - [vagrant-libvirt](vagrant_libvirt.md)
