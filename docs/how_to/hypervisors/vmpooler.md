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

Users with Puppet credentials can follow our instructions for getting & using
vmpooler tokens in our
[internal documentation](https://confluence.puppetlabs.com/pages/viewpage.action?spaceKey=SRE&title=Generating+and+using+vmpooler+tokens).