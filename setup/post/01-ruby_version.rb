# Add Ruby vers to host config section 
# Subscripted assignment to the Host class delegates assignment
# to the corresponding hash from Config['HOSTS']
#
# Need to run this post install as PE hosts will not have ruby installed
# until post install

def get_cmd(host)
  if host.is_pe?
    "#{host['puppetbindir']}/ruby -v"
  else
    'ruby -v'
  end
end

hosts.each do |host|
  if host['platform'] =~ /win/ && host.is_pe?
    host[:ruby_ver] = '1.8.7'
  else
    on(host, get_cmd(host)) do
     host[:ruby_ver] = stdout
    end
  end
end
