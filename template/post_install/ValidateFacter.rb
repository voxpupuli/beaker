
step "Validate Facter Install"
hosts.each { |host|
  on host,"#{host['puppetbinpath']}/facter --version"
}
