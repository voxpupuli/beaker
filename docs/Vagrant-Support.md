For testing against local Vagrant boxes.  As a prerequisite the **Vagrant 1.7+** package needs to installed - see <a href = "http://downloads.vagrantup.com/">downloads.vagrantup.com</a> for downloads.

Currently, we provide a suite of pre-built, publicly available vagrant boxes for use in constructing tests: <a href = "https://vagrantcloud.com/puppetlabs/">Puppet Labs Vagrant Boxes</a>.  You can use these boxes easily by pulling one of our [Example Vagrant Hosts Files](Example-Vagrant-Hosts-Files.md).  

The vm is identified by `box` or `box_url` in the config file.  No snapshot name is required as the vm is reverted back to original state post testing using `vagrant destroy --force`.

### example Vagrant hosts file ###
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

VagrantFiles are created per host configuration file.  They can be found in the `.vagrant/beaker_vagrant_files` directory of the current working directory in a subdirectory named after the host configuration file.

    > beaker --hosts sample.cfg
    > cd .vagrant/beaker_vagrant_files; ls
    sample.cfg
    > cd sample.c

It is possible to have the VirtualBox VM run with a GUI (i.e. non-headless mode) by specifying ``vb_gui`` of any non-nil value in the config file, i.e.:

### example Vagrant hosts file with vb_gui ###
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
