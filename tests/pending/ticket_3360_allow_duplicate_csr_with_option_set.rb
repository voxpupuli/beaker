test_name "#3360: Allow duplicate CSR when allow_duplicate_certs is on"

agent_hostnames = agents.map {|a| a.to_s}

result = on agents.first, puppet_agent("--configprint server --no-daemonize --debug")

step "Start the master"
on master, puppet_master("--allow_duplicate_certs")

step "Generate a certificate request for the agent"
on agents, "puppet certificate generate `hostname` --ca-location remote"

step "Collect the original certs"

on master, puppet_cert("--sign --all")
original_certs = on master, puppet_cert("--list --all")

old_certs = {}
original_certs.stdout.each_line do |line|
  if line =~ /^\+ (\S+) \((.+)\)$/
    old_certs[$1] = $2
  end
end

step "Make another request with the same certname"
on agents, "puppet certificate generate `hostname` --ca-location remote"

step "Collect the new certs"

on master, puppet_cert("--sign --all")
new_cert_list = on master, puppet_cert("--list --all")

new_certs = {}
new_cert_list.stdout.each_line do |line|
  if line =~ /^\+ (\w+) \((.+)\)$/
    new_certs[$1] = $2
  end
end

step "Verify the certs have changed"

agent_hostnames.each do |host|
  fail_test("#{host} does not have a new signed certificate") if old_certs[host] == new_certs[host]
end
