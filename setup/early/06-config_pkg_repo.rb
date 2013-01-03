test_name "Config Packing Repository"
# Currently, this is specific to Linux
confine :except, :platform => 'windows'

aptcfg = %q{ Acquire::http::Proxy "http://proxy.puppetlabs.lan:3128/"; }
ips_pkg_repo="http://solaris-11-internal-repo.acctest.dc1.puppetlabs.net"
debug_opt = options[:debug] ? 'vh' : ''

def epel_info_for! host
  version = host['platform'].match(/el-(\d+)/)[1]
  if version == '6'
    pkg = 'epel-release-6-8.noarch.rpm'
    url = "http://mirror.itc.virginia.edu/fedora-epel/6/i386/#{pkg}"
  elsif version == '5'
    pkg = 'epel-release-5-4.noarch.rpm'
    url = "http://archive.linux.duke.edu/pub/epel/5/i386/#{pkg}"
  else
    fail_test "I don't understand your platform description!"
  end
  return url
end

if options[:repo_proxy]
  hosts.each do |host|
    case
    when host['platform'] =~ /ubuntu/
      on(host, "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi")
      create_remote_file(host, '/etc/apt/apt.conf', aptcfg)
      on(host, "apt-get -y -f -m update")
    when host['platform'] =~ /debian/
      on(host, "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi")
      create_remote_file(host, '/etc/apt/apt.conf', aptcfg)
      on(host, "apt-get -y -f -m update")
    when host['platform'] =~ /solaris-11/
      on(host,"/usr/bin/pkg unset-publisher solaris || :")
      on(host,"/usr/bin/pkg set-publisher -g %s solaris" % ips_pkg_repo)
    else
      logger.debug "#{host}: repo proxy configuration not modified"
    end
  end
end

if options[:extra_repos]
  hosts.each do |host|
    case
    when host['platform'] =~ /el-/
      result = on(host, 'rpm -qa | grep epel-release', :acceptable_exit_codes => [0,1])
      if result.exit_code == 1
        url = epel_info_for! host
        on host, "rpm -i#{debug_opt} #{url}"
        on host, 'yum clean all && yum makecache'
      end
    else
      logger.debug "#{host}: package repo configuration not modified"
    end
  end
end
