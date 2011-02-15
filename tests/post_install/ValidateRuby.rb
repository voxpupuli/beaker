
step "Validate Ruby Install"
hosts.each { |host|
  on host,"#{host['puppetbinpath']}/ruby --version"
}
