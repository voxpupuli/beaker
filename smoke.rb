@hosts.each do |host|
  on host, 'echo hello'
  puts "platform: #{host['platform']}"
  host.reboot
  on host, 'echo itworked'
  # puts "puppet user: #{puppet_user host}"
  # puts "puppet user: #{host.puppet['user']}"
end
