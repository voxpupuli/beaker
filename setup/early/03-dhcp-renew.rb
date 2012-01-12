test_name "renew DHCP lease"
unless options[:dhcp_renew]
  skip_test "Skipping DHCP renew"
else
  step "renew dhcpd with dhclient -r && dhclient or dhcpcd -n eth0"
  hosts.each do |host|
    next if host['platform'].include?('solaris')
      if host['platform'].include? 'sles'
        on host, "dhcpcd -n eth0"
      else
        on host, "dhclient -r && dhclient"
      end
  end
end
