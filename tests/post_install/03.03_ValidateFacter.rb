
step "Validate Facter Install"
on hosts, "/opt/puppet/bin/facter --version"
