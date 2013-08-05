
step "Validate Gem Install"
hosts.each { |host|
  on host,"#{host['puppetbinpath']}/gem --version"
}
