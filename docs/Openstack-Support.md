This options allows for testing against Openstack instances.

Considered **EXPERIMENTAL**, may break without notice.

### Basic Openstack hosts file ###
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
      centos-6-agent:
        roles:
          - agent
        platform: el-6-x86_64
        image: centos-6-x86_64-nocm
        flavor: m1.large
        hypervisor: openstack
    CONFIG:
      nfs_server: none
      consoleport: 443
      openstack_api_key: P1as$w0rd
      openstack_username: user
      openstack_auth_url: http://10.10.10.10:5000/v2.0/tokens
      openstack_tenant: testing
      openstack_network : testing
      openstack_keyname : nopass
