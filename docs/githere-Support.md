The harness can use vms and snapshots that live within vSphere as well.
To do this create a `~/.fog` file with your vSphere credentials:

### example .fog file ###

    :default:
      :vsphere_server: 'vsphere.example.com'
      :vsphere_username: 'joe'
      :vsphere_password: 'MyP@$$w0rd'
      :vmpooler_token: 'randomtokentext'

The vmpooler_token can be used with https://github.com/puppetlabs/vmpooler. Users with Puppet Labs credentials can follow directions for getting and using tokens at https://confluence.puppetlabs.com/display/QE/Generating+and+using+vmpooler+tokens.

These follow the conventions used by Cloud Provisioner and Fog.

There are two possible `hypervisor` hypervisor-types to use for vSphere testing, `vsphere` and `vcloud`.

### `hypervisor: vsphere`
This option locates an existing static VM, optionally reverts it to a pre-existing snapshot, and runs tests on it.

### `hypervisor: vcloud`
This option clones a new VM from a pre-existing template, runs tests on the newly-provisioned clone, then deletes the clone once testing completes.

The `vcloud` option requires a slightly-modified test configuration file, specifying both the target template as well as three additional parameters in the 'CONFIG' section ('datastore', 'resourcepool', and 'folder').

#### example vcloud hosts file ###
    HOSTS:
      master-vm:
        roles:
          - master
          - agent
          - dashboard
        platform: ubuntu-10.04-amd64
        template: ubuntu-1004-x86_64
        hypervisor: vcloud
      agent-vm:
        roles:
          - agent
        platform: ubuntu-10.04-i386
        template: ubuntu-1004-i386
        hypervisor: vcloud
    CONFIG:
      consoleport: 443
      datastore: instance0
      resourcepool: Delivery/Quality Assurance/FOSS/Dynamic
      folder: delivery/Quality Assurance/FOSS/Dynamic
