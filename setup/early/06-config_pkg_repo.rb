test_name "Config Packing Repository"
# Currently, this is specific to Linux
confine :except, :platform => 'windows'

aptcfg = %q{ Acquire::http::Proxy "http://proxy.puppetlabs.lan:3128/"; }

unless options[:pkg_repo]
  skip_test "Skipping Config Packing Repository"
else
  hosts.each do |host|
    case
    when host['platform'] =~ /ubuntu/
      on(host, "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi")
      create_remote_file(host, '/etc/apt/apt.conf', aptcfg)
      on(host, "apt-get -y -f -m update")
    else
      logger.notify "#{host}: packing configuration not modified"
    end
  end
end
