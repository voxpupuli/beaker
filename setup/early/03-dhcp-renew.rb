test_name "renew dhcpd lease so we don't hiccup in the tests"

step "renew dhcpd with dhclient -r && dhclient or dhcpd -n eth0"

hosts.each do |host|
  if host['platform'].include? 'sles'
    on host, "dhcpd -n eth0"
  else
    on host, "dhclient -r && dhclient"
  end
end

