# Add Ruby vers to host config section 
# Subscripted assignment to the Host class delegates assignment
# to the corresponding hash from Config['HOSTS']
#
# Need to run this post install as PE hosts will not have ruby installed
# until post install

hosts.each do |host|
  on(host, "ruby -v || #{config['puppetpath']}/bin/ruby -v") do
   host[:ruby_ver] = stdout
  end
end
