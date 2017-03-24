[vmpooler](https://github.com/puppetlabs/vmpooler) is a puppet-built abstraction
layer over vSphere infrastructure that pools VMs to be used by beaker & other
systems.

beaker's vmpooler hypervisor interacts with vmpooler to get Systems Under Test
(SUTs) for testing purposes.

# Tokens

Using tokens will allow you to extend your VMs lifetime, as well as interact
with vmpooler and your VMs in more complex ways. You can have beaker do these
same things by providing your `vmpooler_token` in the `~/.fog` file. For more
info about how the `.fog` file works, please refer to the
[hypervisor README](README.md).

An example of a `.fog` file with just the vmpooler details is below:
```yaml
:default:
  :vmpooler_token: 'randomtokentext'
```
# Additional Disks
Using the vmpooler API, Beaker enables you to attach additional storage disks in the host configuration file. The disks are added at the time the VM is created. Logic for using the disk must go into your tests.

Simply add the `disks` key and a list containing the sizes(in GB) of the disks you want to create and attach to that host.
For example, to create 2 disks sized 8GB and 16GB to example-box:

```yaml
 example-box:
    disks:
      - 8
      - 16
    roles:
      - satellite
    platform: el-7-x86_64
    hypervisor: vmpooler
    template: redhat-7-x86_64
```

Users with Puppet credentials can follow our instructions for getting & using
vmpooler tokens in our
[internal documentation](https://confluence.puppetlabs.com/pages/viewpage.action?spaceKey=SRE&title=Generating+and+using+vmpooler+tokens).
