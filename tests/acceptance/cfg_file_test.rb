test_name "Validate puppet.conf vs.--configprint all"

puppet_conf_h  = Hash.new 
config_print_h = Hash.new 

step "get puppet.conf file contents"
on master, "cat /etc/puppetlabs/puppet/puppet.conf | tr -d \" \"" do
  stdout.split("\n").select{ |v| v =~ /=/ }.each do |line|
    k,v = line.split("=")
    puppet_conf_h[k]=v 
  end
  #puts puppet_conf_h.inspect
end

step "get --configprint output"
on master, puppet_master("--configprint all | tr -d \" \"") do
  stdout.split("\n").select{ |v| v =~ /=/ }.each do |line|
    k,v = line.split("=")
    config_print_h[k]=v 
  end
  #puts config_print_h.inspect
   #fail_test "puppet master wasn't mentioned" unless stdout.include? 'should fail'
end
