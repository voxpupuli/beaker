Pre-requisite: Fission gem installed and configured, including a `~/.fissionrc`
that points to the `vmrun` executable and where virtual machines can be found.
  Example `.fissionrc` file (it's YAML):

    vm_dir: "/Directory/containing/my/.vmwarevm/files/"
    vmrun_bin: "/Applications/VMware Fusion.app/Contents/Library/vmrun"

You can then use the following arguments in the node configuration:
- `hypervisor: fusion` tells us to enable this feature for this host. This is required.
- `snapshot: <name>`, where <name> is the snapshot name to revert to.  This is required.

We'll try and match up the hostname with a VM of the same name. Note that the VM is expected to be pre-configured for running acceptance tests; it should have all the right prerequisite libraries, password-less SSH access for root, etc.

There are a few additional options available in your configuration file. Each host
section can now use:

- `vmname`: This is useful if the hostname of the VM doesn't match the name of
  the `.vmwarevm` file on disk. The alias should be something fission can load.


### Basic VMWare fusion hosts file ###

    HOSTS:
      pe-debian6:
        roles:
          - master
          - agent
        platform: debian-6-i386
        vmname: super-awesome-vm-name
        hypervisor: fusion
        snapshot: acceptance-testing-5

### Diagnostics ###

When using `hypervisor fusion`, we'll log all the available VM names and for each
host we'll log all the available snapshot names.
