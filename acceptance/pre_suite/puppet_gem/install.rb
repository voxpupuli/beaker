hosts.each do |host|
  install_puppet_from_gem(host, {:version => '3.7.5'})

  if host['platform'] =~ /sles/
    host.mkdir_p(host['puppetbindir'])
    ['facter', 'hiera', 'puppet'].each do |tool|
      on host, "ln -s /usr/bin/#{tool}.ruby* #{host['puppetbindir']}/#{tool}"
    end
  end
end