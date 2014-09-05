[ 'command', "dsl/patterns" ].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  #Provides convienience methods for commonly run actions on hosts
  module HostPrebuiltSteps
    include Beaker::DSL::Patterns

    NTPSERVER = 'pool.ntp.org'
    SLEEPWAIT = 5
    TRIES = 5
    UNIX_PACKAGES = ['curl', 'ntpdate']
    WINDOWS_PACKAGES = ['curl']
    SLES_PACKAGES = ['curl', 'ntp']
    DEBIAN_PACKAGES = ['curl', 'ntpdate', 'lsb-release']
    ETC_HOSTS_PATH = "/etc/hosts"
    ETC_HOSTS_PATH_SOLARIS = "/etc/inet/hosts"
    ROOT_KEYS_SCRIPT = "https://raw.githubusercontent.com/puppetlabs/puppetlabs-sshkeys/master/templates/scripts/manage_root_authorized_keys"
    ROOT_KEYS_SYNC_CMD = "curl -k -o - -L #{ROOT_KEYS_SCRIPT} | %s"
    APT_CFG = %q{ Acquire::http::Proxy "http://proxy.puppetlabs.net:3128/"; }
    IPS_PKG_REPO="http://solaris-11-internal-repo.delivery.puppetlabs.net"

    #Run timesync on the provided hosts
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def timesync host, opts
      logger = opts[:logger]
      block_on host do |host|
        logger.notify "Update system time sync for '#{host.name}'"
        if host['platform'].include? 'windows'
          # The exit code of 5 is for Windows 2008 systems where the w32tm /register command
          # is not actually necessary.
          host.exec(Command.new("w32tm /register"), :acceptable_exit_codes => [0,5])
          host.exec(Command.new("net start w32time"), :acceptable_exit_codes => [0,2])
          host.exec(Command.new("w32tm /config /manualpeerlist:#{NTPSERVER} /syncfromflags:manual /update"))
          host.exec(Command.new("w32tm /resync"))
          logger.notify "NTP date succeeded on #{host}"
        else
          case
            when host['platform'] =~ /solaris-10/
              ntp_command = "sleep 10 && ntpdate -w #{NTPSERVER}"
            when host['platform'] =~ /sles-/
              ntp_command = "sntp #{NTPSERVER}"
            else
              ntp_command = "ntpdate -t 20 #{NTPSERVER}"
          end
          success=false
          try = 0
          until try >= TRIES do
            try += 1
            if host.exec(Command.new(ntp_command), :acceptable_exit_codes => (0..255)).exit_code == 0
              success=true
              break
            end
            sleep SLEEPWAIT
          end
          if success
            logger.notify "NTP date succeeded on #{host} after #{try} tries"
          else
            raise "NTP date was not successful after #{try} tries"
          end
        end
      end
    rescue => e
      report_and_raise(logger, e, "timesync (--ntp)")
    end

    #Validate that hosts are prepared to be used as SUTs, if packages are missing attempt to
    #install them.  Verifies the presence of #{HostPrebuiltSteps::UNIX_PACKAGES} on unix platform hosts,
    #{HostPrebuiltSteps::SLES_PACKAGES} on SUSE platform hosts, #{HostPrebuiltSteps::DEBIAN_PACKAGES on debian platform
    #hosts and {HostPrebuiltSteps::WINDOWS_PACKAGES} on windows
    #platforms.
    # @param [Host, Array<Host>, String, Symbol] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def validate_host host, opts
      logger = opts[:logger]
      block_on host do |host|
        case
        when host['platform'] =~ /sles-/
          SLES_PACKAGES.each do |pkg|
            if not host.check_for_package pkg
              host.install_package pkg
            end
          end
        when host['platform'] =~ /debian/
          DEBIAN_PACKAGES.each do |pkg|
            if not host.check_for_package pkg
              host.install_package pkg
            end
          end
        when host['platform'] =~ /windows/
          WINDOWS_PACKAGES.each do |pkg|
            if not host.check_for_package pkg
              host.install_package pkg
            end
          end
        when host['platform'] !~ /debian|aix|solaris|windows|sles-|osx-/
          UNIX_PACKAGES.each do |pkg|
            if not host.check_for_package pkg
              host.install_package pkg
            end
          end
        end
      end
    rescue => e
      report_and_raise(logger, e, "validate")
    end

    #Install a set of authorized keys using {HostPrebuiltSteps::ROOT_KEYS_SCRIPT}.  This is a
    #convenience method to allow for easy login to hosts after they have been provisioned with
    #Beaker.
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def sync_root_keys host, opts
      # JJM This step runs on every system under test right now.  We're anticipating
      # issues on Windows and maybe Solaris.  We will likely need to filter this step
      # but we're deliberately taking the approach of "assume it will work, fix it
      # when reality dictates otherwise"
      logger = opts[:logger]
      block_on host do |host|
      logger.notify "Sync root authorized_keys from github on #{host.name}"
        # Allow all exit code, as this operation is unlikely to cause problems if it fails.
        if host['platform'].include? 'solaris'
          host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "bash"), :acceptable_exit_codes => (0..255))
        else
          host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "env PATH=/usr/gnu/bin:$PATH bash"), :acceptable_exit_codes => (0..255))
        end
      end
    rescue => e
      report_and_raise(logger, e, "sync_root_keys")
    end

    #Determine the Extra Packages for Enterprise Linux URL for the provided Enterprise Linux host.
    # @param [Host] host One host to act upon
    # @return [String] The URL for EPL for the provided host
    # @raise [Exception] Raises an error if the host provided's platform != /el-(5|6)/
    def epel_info_for! host
      version = host['platform'].match(/el-(\d+)/)
      if not version
        raise "epel_info_for! not available for #{host.name} on platform #{host['platform']}"
      end
      version = version[1]
      if version == '6'
        pkg = 'epel-release-6-8.noarch.rpm'
        url = "http://mirror.itc.virginia.edu/fedora-epel/6/i386/#{pkg}"
      elsif version == '5'
        pkg = 'epel-release-5-4.noarch.rpm'
        url = "http://archive.linux.duke.edu/pub/epel/5/i386/#{pkg}"
      else
        raise "epel_info_for! does not support el version #{version}, on #{host.name}"
      end
      return url
    end

    #Run 'apt-get update' on the provided host or hosts.  If the platform of the provided host is not
    #ubuntu or debian do nothing.
    # @param [Host, Array<Host>] hosts One or more hosts to act upon
    def apt_get_update hosts
      block_on hosts do |host|
        if host[:platform] =~ /(ubuntu)|(debian)/
          host.exec(Command.new("apt-get update"))
        end
      end
    end

    #Create a file on host or hosts at the provided file path with the provided file contents.
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [String] file_path The path at which the new file will be created on the host or hosts.
    # @param [String] file_content The contents of the file to be created on the host or hosts.
    def copy_file_to_remote(host, file_path, file_content)
      block_on host do |host|
        Tempfile.open 'beaker' do |tempfile|
          File.open(tempfile.path, 'w') {|file| file.puts file_content }

          host.do_scp_to(tempfile.path, file_path, @options)
        end
      end
    end

    #Alter apt configuration on ubuntu and debian host or hosts to internal Puppet Labs
    # proxy {HostPrebuiltSteps::APT_CFG} proxy, alter pkg on solaris-11 host or hosts
    # to point to interal Puppetlabs proxy {HostPrebuiltSteps::IPS_PKG_REPO}. Do nothing
    # on non-ubuntu, debian or solaris-11 platform host or hosts.
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def proxy_config( host, opts )
      # repo_proxy
      # supports ubuntu, debian and solaris platforms
      logger = opts[:logger]
      block_on host do |host|
        case
        when host['platform'] =~ /ubuntu/
          host.exec(Command.new("if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi"))
          copy_file_to_remote(host, '/etc/apt/apt.conf', APT_CFG)
          apt_get_update(host)
        when host['platform'] =~ /debian/
          host.exec(Command.new("if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi"))
          copy_file_to_remote(host, '/etc/apt/apt.conf', APT_CFG)
          apt_get_update(host)
        when host['platform'] =~ /solaris-11/
          host.exec(Command.new("/usr/bin/pkg unset-publisher solaris || :"))
          host.exec(Command.new("/usr/bin/pkg set-publisher -g %s solaris" % IPS_PKG_REPO))
        else
          logger.debug "#{host}: repo proxy configuration not modified"
        end
      end
    rescue => e
      report_and_raise(logger, e, "proxy_config")
    end

    #Install EPEL on host or hosts with platform = /el-(5|6)/.  Do nothing on host or hosts of other platforms.
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Boolean] :debug If true, print verbose rpm information when installing EPEL
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def add_el_extras( host, opts )
      #add_el_extras
      #only supports el-* platforms
      logger = opts[:logger]
      debug_opt = opts[:debug] ? 'vh' : ''
      block_on host do |host|
        case
        when host['platform'] =~ /el-(5|6)/
          result = host.exec(Command.new('rpm -qa | grep epel-release'), :acceptable_exit_codes => [0,1])
          if result.exit_code == 1
            url = epel_info_for! host
            host.exec(Command.new("rpm -i#{debug_opt} #{url}"))
            host.exec(Command.new('yum clean all && yum makecache'))
          end
        else
          logger.debug "#{host}: package repo configuration not modified"
        end
      end
    rescue => e
      report_and_raise(logger, e, "add_repos")
    end

    #Determine the domain name of the provided host from its /etc/resolv.conf
    # @param [Host] host the host to act upon
    def get_domain_name(host)
      domain = nil
      search = nil
      resolv_conf = host.exec(Command.new("cat /etc/resolv.conf")).stdout
      resolv_conf.each_line { |line|
        if line =~ /^\s*domain\s+(\S+)/
          domain = $1
        elsif line =~ /^\s*search\s+(\S+)/
          search = $1
        end
      }
      return domain if domain
      return search if search
    end

    #Determine the ip address of the provided host
    # @param [Host] host the host to act upon
    # @deprecated use {Host#get_ip}
    def get_ip(host)
      host.get_ip
    end

    #Append the provided string to the /etc/hosts file of the provided host
    # @param [Host] host the host to act upon
    # @param [String] etc_hosts The string to append to the /etc/hosts file
    def set_etc_hosts(host, etc_hosts)
      host.exec(Command.new("echo '#{etc_hosts}' > /etc/hosts"))
    end

    #Make it possible to log in as root by copying the current users ssh keys to the root account
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def copy_ssh_to_root host, opts
      logger = opts[:logger]
      block_on host do |host|
        logger.debug "Give root a copy of current user's keys, on #{host.name}"
        if host['platform'] =~ /windows/
          host.exec(Command.new('cp -r .ssh /cygdrive/c/Users/Administrator/.'))
          host.exec(Command.new('chown -R Administrator /cygdrive/c/Users/Administrator/.ssh'))
        else
          host.exec(Command.new('sudo su -c "cp -r .ssh /root/."'), {:pty => true})
        end
      end
    end

    #Update /etc/hosts to make it possible for each provided host to reach each other host by name.
    #Assumes that each provided host has host[:ip] set.
    # @param [Host, Array<Host>] hosts An array of hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def hack_etc_hosts hosts, opts
      etc_hosts = "127.0.0.1\tlocalhost localhost.localdomain\n"
      hosts.each do |host|
        etc_hosts += "#{host['ip'].to_s}\t#{host[:vmhostname] || host.name}\n"
      end
      hosts.each do |host|
        set_etc_hosts(host, etc_hosts)
      end
    end

    #Update sshd_config on debian, ubuntu, centos, el, redhat and fedora boxes to allow for root login, does nothing on other platfoms
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def enable_root_login host, opts
      logger = opts[:logger]
      block_on host do |host|
        logger.debug "Update /etc/ssh/sshd_config to allow root login"
        host.exec(Command.new("sudo su -c \"sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config\""), {:pty => true}
  )
        #restart sshd
        if host['platform'] =~ /debian|ubuntu/
          host.exec(Command.new("sudo su -c \"service ssh restart\""), {:pty => true})
        elsif host['platform'] =~ /centos|el-|redhat|fedora/
          host.exec(Command.new("sudo su -c \"service sshd restart\""), {:pty => true})
        else
          @logger.warn("Attempting to update ssh on non-supported platform: #{host.name}: #{host['platform']}")
        end
      end
    end

    #Disable SELinux on centos, does nothing on other platforms
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def disable_se_linux host, opts
      logger = opts[:logger]
      block_on host do |host|
        if host['platform'] =~ /centos|el-|redhat|fedora/
          @logger.debug("Disabling se_linux on #{host.name}")
          host.exec(Command.new("sudo su -c \"setenforce 0\""), {:pty => true})
        else
          @logger.warn("Attempting to disable SELinux on non-supported platform: #{host.name}: #{host['platform']}")
        end
      end
    end

    #Disable iptables on centos, does nothing on other platforms
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def disable_iptables host, opts
      logger = opts[:logger]
      block_on host do |host|
        if host['platform'] =~ /centos|el-|redhat|fedora/
          logger.debug("Disabling iptables on #{host.name}")
          host.exec(Command.new("sudo su -c \"/etc/init.d/iptables stop\""), {:pty => true})
        else
          logger.warn("Attempting to disable iptables on non-supported platform: #{host.name}: #{host['platform']}")
        end
      end
    end

    # Setup files for enabling requests to pass to a proxy server
    # This works for the APT package manager on debian and ubuntu
    # and YUM package manager on el, centos, fedora and redhat.
    # @param [Host, Array<Host>, String, Symbol] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def package_proxy host, opts
      logger = opts[:logger]

      block_on host do |host|
        logger.debug("enabling proxy support on #{host.name}")
        case host['platform']
          when /ubuntu/, /debian/
            host.exec(Command.new("echo 'Acquire::http::Proxy \"#{opts[:package_proxy]}/\";' >> /etc/apt/apt.conf.d/10proxy"))
          when /^el-/, /centos/, /fedora/, /redhat/
            host.exec(Command.new("echo 'proxy=#{opts[:package_proxy]}/' >> /etc/yum.conf"))
        else
          logger.debug("Attempting to enable package manager proxy support on non-supported platform: #{host.name}: #{host['platform']}")
        end
      end
    end

  end

end
