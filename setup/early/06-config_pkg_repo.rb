test_name "Config Packing Repository"
# Currently, this is specific to Linux
confine :except, :platform => 'windows'

aptcfg = %q{ Acquire::http::Proxy "http://proxy.puppetlabs.lan:3128/"; }
ips_pkg_repo="http://solaris-11-internal-repo.acctest.dc1.puppetlabs.net"

unless options[:pkg_repo]
  skip_test "Skipping Config Packing Repository"
else
  hosts.each do |host|
    case
    when host['platform'] =~ /ubuntu/
      on(host, "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi")
      create_remote_file(host, '/etc/apt/apt.conf', aptcfg)
      on(host, "apt-get -y -f -m update")
    when host['platform'] =~ /debian/
      on(host, "apt-get -y -f -m update")
    when host['platform'] =~ /solaris/
      on(host,"/usr/bin/pkg unset-publisher solaris || :")
      on(host,"/usr/bin/pkg set-publisher -g %s solaris" % ips_pkg_repo)
    else
      logger.notify "#{host}: packing configuration not modified"
    end
  end
end
