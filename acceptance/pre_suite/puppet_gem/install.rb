hosts.each do |host|
  install_puppet_from_gem_on(host, {:version => '3.8.7'})
  unless host['platform'] =~ /windows/
    on(host, "touch #{File.join(host.puppet_configprint['confdir'],'puppet.conf')}")
    on(host, puppet('resource user puppet ensure=present'))
    on(host, puppet('resource group puppet ensure=present'))
  end
end
