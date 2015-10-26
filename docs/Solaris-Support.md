Used with `hypervisor: solaris`, the harness can connect to a Solaris host via SSH and revert zone snapshots.

### example .fog file ###
    :default:
      :solaris_hypervisor_server: solaris.example.com
      :solaris_hypervisor_username: harness
      :solaris_hypervisor_keyfile: /home/jenkins/.ssh/id_rsa-harness
      :solaris_hypervisor_vmpath: rpool/zoneds
      :solaris_hypervisor_snappaths:
        - rpool/ROOT/solaris
