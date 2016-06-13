# Openstack

OpenStack is a free and open-source software platform for cloud computing. [Their Site](http://www.openstack.org/).

Considered **EXPERIMENTAL**, may break without notice.

# Getting Started

### Requirements

Get openstack Access & Security credentials:

- "openstack_api_key"
- "openstack_auth_url" 
- "openstack_username"
- "openstack_tenant"
- "openstack_network"
- "openstack_keyname"

If you are using [OpenStack Dashboard "Horizon"] (https://wiki.openstack.org/wiki/Horizon) 
you can find these keys in next places:

1. login to "Horizon dashboard" -> "project" -> "Compute" -> "Access & Security" -> tab "API Access" -> "Download OpenStack RC File":
   * "openstack_auth_url" == OS_AUTH_URL + "/tokens"
   * "openstack_username" == OS_USERNAME
   * "openstack_tenant" == OS_TENANT_NAME
2. "openstack_network": in "project" -> "Networks"
3. "openstack_keyname": in "project" -> "Compute" -> "Access & Security" -> tab "Key Pairs"
4. "openstack_api_key": Your user Password

### Setup a Openstack Hosts File

An Openstack hosts file looks like a typical hosts file, 
except that there are a number of required properties that need to be added to every host 
in order for the Openstack hypervisor to provision hosts properly.

**Basic Openstack hosts file**

    HOSTS:
      centos-6-master:
        roles:
          - master
          - agent
          - database
          - dashboard
        platform: el-6-x86_64
        hypervisor: openstack
        image: centos-6-x86_64-nocm
        flavor: m1.large
        
    CONFIG:
      nfs_server: none
      consoleport: 443
      openstack_api_key: Pas$w0rd
      openstack_username: user
      openstack_auth_url: http://10.10.10.10:5000/v2.0/tokens
      openstack_tenant: testing
      openstack_network : testing
      openstack_keyname : nopass

The `image` - image name.

The `flavor` - templates for VMs, defining sizes for RAM, disk, number of cores, and so on.


# Openstack-Specific Hosts File Settings

### user-data

"user data" - a blob of data that the user can specify when they launch an instance. 
The instance can access this data through the metadata service or config drive with one of the next requests:

- curl http://169.254.169.254/2009-04-04/user-data
- curl http://169.254.169.254/openstack/2012-08-10/user_data


Examples of `user_data` you can find here: http://cloudinit.readthedocs.io/en/latest/topics/examples.html

Also if you plan use `user-data` make sure that 'cloud-init' package installed in your VM `image` and 'cloud-init' service is running.

**Example Openstack hosts file with user_data**

    HOSTS:
      centos-6-master:
        roles:
          - master
          - agent
          - database
          - dashboard
        platform: el-6-x86_64
        image: centos-6-x86_64-nocm
        flavor: m1.large
        hypervisor: openstack
        user_data: |
          #cloud-config
          bootcmd:
            - echo 123 > /tmp/test.txt
    CONFIG:
      nfs_server: none
      consoleport: 443
      openstack_api_key: P1as$w0rd
      openstack_username: user
      openstack_auth_url: http://10.10.10.10:5000/v2.0/tokens
      openstack_tenant: testing
      openstack_network : testing
      openstack_keyname : nopass


