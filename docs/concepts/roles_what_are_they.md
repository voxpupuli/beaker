Each host in a host configuration file is defined to have one or more roles.  Beaker supports the roles `master`, `agent`, `frictionless`, `dashboard` and `database`.  These roles indicate what Puppet responsibilities the host will assume.  If puppet is installed as part of the Beaker test execution then the roles will be honored (ie, the host defined as `master` will become the puppet master node).  Other than puppet installation, the roles provide short cuts to node access.  In tests you can refer to nodes by role:

    on master, "echo hello"
    on database, "echo hello"

## Creating Your Own Roles
Arbitrary role creating is supported in Beaker.  New roles are created as they are discovered in the host/config file provided at runtime.

### Example User Role Creation
```
HOSTS:
  pe-ubuntu-lucid:
    roles:
      - agent
      - dashboard
      - database
      - master
      - nodes
      - ubuntu
    vmname : pe-ubuntu-lucid
    platform: ubuntu-10.04-i386
    snapshot : clean-w-keys
    hypervisor : fusion
  pe-centos6:
    roles:
      - agent
      - nodes
      - centos
    vmname : pe-centos6
    platform: el-6-i386
    hypervisor : fusion
    snapshot: clean-w-keys
CONFIG:
  nfs_server: none
  consoleport: 443
```

In this case I've created the new roles `nodes`, `centos` and `ubuntu`.  These roles can now be used to call any Beaker DSL methods that require a host.

```
on centos, 'echo I'm the centos box'
on ubuntu, 'echo I'm the ubuntu box'
on nodes, 'echo this command will be executed on both defined hosts'
```
