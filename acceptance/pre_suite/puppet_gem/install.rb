hosts.each do |host|
  install_puppet_from_gem(host, {:version => '3.7.5'})
end