test_name "Validate Sign Cert"

step "Master: Start Puppet Master"
on master, puppet_master("--certdnsnames=\"puppet:$(hostname):$(hostname -f)\" --verbose")

#step "Puppet Master clean and generate agent certs"
#on master,"puppet cert --clean #{agents.join(' ')}"
#on master,"puppet cert --generate #{agents.join(' ')}"
#on master,"puppet cert --sign --all"

sleep 1
step "Agents: Run agent --test first time to gen CSR "
agents.each { |agent|
  on agent, "puppet agent -t", :acceptable_exit_codes => [1]
}

# Sign all waiting certs
step "Master: sign all certs"
on master,"puppet cert --sign --all"
