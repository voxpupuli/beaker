
step "Validate Puppet Install"
hosts.each { |host|
  on host,"#{host['puppetbinpath']}/puppet --version"
}
