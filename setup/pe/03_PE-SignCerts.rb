# Agents certs will remain waiting for signing on master until this step
#

step 'Sign Requested Agent Certs'
on(master, puppet("cert --sign --all"), :acceptable_exit_codes => [0,24])

agents.each do |agent|
  next unless agent['roles'].length == 1 and agent['roles'].include?('agent')

  (0..10).each do |i|
    step "Checking if cert issued for #{agent} (#{i})"

    # puppet cert --list <IP> fails, so list all
    break if on(master, puppet("cert --list --all")).stdout =~ /^#{Regexp.escape("+ \"#{agent.name}\"")}/

    fail_test("Failed to sign cert for #{agent}") if i == 10

    step "Wait for agent #{agent}: #{i}"
    sleep 10
    on(master, puppet("cert --sign --all"), :acceptable_exit_codes => [0,24])
  end
end
