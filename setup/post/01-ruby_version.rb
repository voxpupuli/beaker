# Add Ruby vers to host config section 
# Subscripted assignment to the Host class delegates assignment
# to the corresponding hash from Config['HOSTS']
#
# Need to run this post install as PE hosts will not have ruby installed
# until post install

if options[:type] =~ /pe/
  cmd = "#{config['puppetbindir']}/ruby -v"
else
  cmd = 'ruby -v'
end 

hosts.each do |host|
  on(host, "#{cmd}") do
   host[:ruby_ver] = stdout
  end
end
