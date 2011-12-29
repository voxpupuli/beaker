# Root SSH authorized keys #

The current list of known SSH public keys for technical people at Puppet Labs
will be automatically downloaded from
[puppetlabs-sshkeys](https://github.com/puppetlabs/puppetlabs-sshkeys) from the
setup early phase scripts.  If this does not work, please use the
--no-root-keys command line option to disable this behavior.

The behavior for this setup step is located in the following script:

    setup/early/20-root_authorized_keys.rb

# Timeouts #

The DHCP renewal appears to disconnect the target host from the network before
the command to renew the lease is issued.  This leaves the target node orphaned
and subsequent tests block until a TIMEOUT expires.

I ran into this on CentOS 6 systems and have added the `--dhcp-renew` option to
work around the issue.  DHCP renewal will not be performed without this option.

EOF
