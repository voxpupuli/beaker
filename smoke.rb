# @hosts.each do |host|
#   on host, 'echo hello'
#   puts "platform: #{host['platform']}"
#   host.reboot
#   on host, 'echo itworked'
#   # puts "puppet user: #{puppet_user host}"
#   # puts "puppet user: #{host.puppet['user']}"
# end

block_on @hosts, {:run_in_parallel => true} do |host|
  host.reboot
end
