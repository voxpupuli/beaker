require 'yaml'
keypair=@options[:keypair]
host_config_file='tmp/host_config.yaml'
save_config_file='tmp/host_save_config.yaml'
keyfile=@options[:keyfile]

skip_test 'will not run without a keyfile and keypair' and break unless keypair and keyfile

# sets up a cloud master
# requies that pe-build is in the $PATH
controller = nil
hosts.each do |host|
  if host['roles'].include? 'controller'
    controller = host
  end
end

skip_test 'not running test if there is no controller' and break unless controller

my_master = nil
hosts.each do |host|
  my_master = host if host['roles'].include? 'master'
end

skip_test 'we don\'t need to create a master if one was specified. Its up to the user to be sure that the hostname of their master is accessible from ec2' and break if my_master

step 'creating a puppetmaster node in ec2'

# create ec2 instances for master and dashboard
puts `pe-builder --type t1.micro --keypair #{keypair} --keyfile #{keyfile} --os centos56 --number 1 --cfgfile #{host_config_file} --verbose`

# add the host entries to current list of hosts
host_config = YAML.load_file(host_config_file)['HOSTS']
host_config.collect { |name,overrides| @hosts.push(Host.create(name,overrides,@config)) }


# save the current configuration
File.open(save_config_file, 'w') do |fh|
  fh.write YAML.dump(self.to_hash)
end
