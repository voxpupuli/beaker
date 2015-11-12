When using the Vagrant Hypervisor, beaker can mount specific local directories as synced_folders inside the vagrant box.
This is done by using the 'mount_folders' option in the nodeset file.

Example hosts file:

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

In the above beaker will mount the folders ./ to /vagrant/folder1 and the folder /tmp to /vagrant/tmp

## Supported Virtualization Providers ##
* [Vagrant](Vagrant-Support.md)