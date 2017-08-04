# The Hypervisors Directory

This directory contains docs explaining any peculiarities or details of a particular
hypervisor's implementation.

If you don't see a file here for a hypervisor, then it's either not yet documented
(feel free to help us out here!), or it should conform to our normal hypervisor
assumptions.

# Credentials File

Beaker uses credentials from a `.fog` file for authentication. This file came
from using the [fog cloud services library](http://fog.io). Beaker now only uses
fog functionality in the openstack hypervisor, but we still use the `.fog` file
for a credentials store.

By default, the file is located under the user's home directory. This helps to
keep the credentials confidential. The path of `.fog` file can be changed by
setting the `dot_fog` global beaker option.

The `.fog` file is written in YAML. The keys are particular to the service that
they correspond to, and each hypervisor's documentation should include the keys
that are needed for it. An example `.fog` file is below:

```yaml
:default:
  :vsphere_server: 'vsphere.example.com'
  :vsphere_username: 'joe'
  :vsphere_password: 'MyP@$$w0rd'
  :vmpooler_token: 'randomtokentext'
```

# External Hypervisors

Puppetlabs and its community have made several gems that support different hypervisors with beaker, the reason for this is that we're looking to decrease Beaker's
dependency footprint, and hypervisors are one of the places where we can often
increase the load across all Beaker uses to benefit a small group that uses a
particular hypervisor. 

In order to offset this, we've made a listing of gems and community-supported forks that support other external hypervisors. Please check them out if you'd like to use those hypervisors, hopefully it'll save you from spending time trying to support a new hypervisor yourself.

Hypervisor gems made by puppet (pre-included in beaker 3.x):

| Hypervisor               | Fork                                                               |
| :----------------------: | :---------------------------------------------------------:        |
| Vmpooler                 | [beaker-vmpooler](https://github.com/puppetlabs/beaker-vmpooler)   |
| Vcloud                   | [beaker-vcloud](https://github.com/puppetlabs/beaker-vcloud)       |
| AWS                      | [beaker-aws](https://github.com/puppetlabs/beaker-aws)             |
| Vagrant                  | [beaker-vagrant](https://github.com/puppetlabs/beaker-vagrant)     |
| VMware/Vsphere           | [beaker-vmware](https://github.com/puppetlabs/beaker-vmware)       |
| Docker                   | [beaker-docker](https://github.com/puppetlabs/beaker-docker)       |
| Openstack                | [beaker-openstack](https://github.com/puppetlabs/beaker-openstack) |
| Google Compute           | [beaker-google](https://github.com/puppetlabs/beaker-google)       |

Hypervisor gems and beaker forks made by community:

| Hypervisor   | Fork                                                                 |
|:------------:|:--------------------------------------------------------------------:|
| LXC          | [Obmondo](https://github.com/Obmondo/beaker)                         |
| DigitalOcean | [beaker-digitalocean](https://github.com/tiengo/beaker-digitalocean) |
