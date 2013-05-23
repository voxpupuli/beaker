module PuppetAcceptance 
  class RepoController

    APT_CFG = %q{ Acquire::http::Proxy "http://proxy.puppetlabs.net:3128/"; }
    IPS_PKG_REPO="http://solaris-11-internal-repo.delivery.puppetlabs.net"

    def initialize(options, hosts)
      @options = options.dup
      @hosts = hosts
      @logger = options[:logger]
      @debug_opt = options[:debug] ? 'vh' : ''
    end

    def epel_info_for! host
      version = host['platform'].match(/el-(\d+)/)[1]
      if version == '6'
        pkg = 'epel-release-6-8.noarch.rpm'
        url = "http://mirror.itc.virginia.edu/fedora-epel/6/i386/#{pkg}"
      elsif version == '5'
        pkg = 'epel-release-5-4.noarch.rpm'
        url = "http://archive.linux.duke.edu/pub/epel/5/i386/#{pkg}"
      else
        raise "I don't understand your platform description!"
      end
      return url
    end

    def apt_get_update
      @hosts.each do |host|
        if host['platform'] =~ /ubuntu|debian/
          host.exec(HostCommand.new("apt-get -y -f -m update"))
        end
      end
    end

    def copy_file_to_remote(host, file_path, file_content)
      Tempfile.open 'puppet-acceptance' do |tempfile|
        File.open(tempfile.path, 'w') {|file| file.puts file_content }

        host.do_scp(tempfile.path, file_path, @options)
      end

    end

    def proxy_config
      # repo_proxy
      # supports ubuntu, debian and solaris platforms
      @hosts.each do |host|
        case
        when host['platform'] =~ /ubuntu/
          host.exec(HostCommand.new("if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi"))
          copy_file_to_remote(host, '/etc/apt/apt.conf', APT_CFG)
          apt_get_update
        when host['platform'] =~ /debian/
          host.exec(HostCommand.new("if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi"))
          copy_file_to_remote(host, '/etc/apt/apt.conf', APT_CFG)
          apt_get_update
        when host['platform'] =~ /solaris-11/
          host.exec(HostCommand.new("/usr/bin/pkg unset-publisher solaris || :"))
          host.exec(HostCommand.new(host,"/usr/bin/pkg set-publisher -g %s solaris" % IPS_PKG_REPO))
        else
          @logger.debug "#{host}: repo proxy configuration not modified"
        end
      end
    end

    def add_repos
      #extra_repos
      #only supports el-* platforms
      @hosts.each do |host|
        case
        when host['platform'] =~ /el-/
          result = host.exec(HostCommand.new('rpm -qa | grep epel-release'), :acceptable_exit_codes => [0,1])
          if result.exit_code == 1
            url = epel_info_for! host
            host.exec(HostCommand.new("rpm -i#{@debug_opt} #{url}"))
            host.exec(HostCommand.new('yum clean all && yum makecache'))
          end
        else
          @logger.debug "#{host}: package repo configuration not modified"
        end
      end
    end

  end
end
