require 'pathname'

[ 'command', "dsl" ].each do |lib|
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
    FREEBSD_PACKAGES = ['curl', 'perl5|perl']
    OPENBSD_PACKAGES = ['curl']
    ARCHLINUX_PACKAGES = ['curl', 'ntp']
    WINDOWS_PACKAGES = ['curl']
    PSWINDOWS_PACKAGES = []
    SLES10_PACKAGES = ['curl']
    SLES_PACKAGES = ['curl', 'ntp']
    DEBIAN_PACKAGES = ['curl', 'ntpdate', 'lsb-release']
    CUMULUS_PACKAGES = ['curl', 'ntpdate']
    SOLARIS10_PACKAGES = ['CSWcurl', 'CSWntp']
    SOLARIS11_PACKAGES = ['curl', 'ntp']
    ETC_HOSTS_PATH = "/etc/hosts"
    ETC_HOSTS_PATH_SOLARIS = "/etc/inet/hosts"
    ROOT_KEYS_SCRIPT = "https://raw.githubusercontent.com/puppetlabs/puppetlabs-sshkeys/master/templates/scripts/manage_root_authorized_keys"
    ROOT_KEYS_SYNC_CMD = "curl -k -o - -L #{ROOT_KEYS_SCRIPT} | %s"
    ROOT_KEYS_SYNC_CMD_AIX = "curl --tlsv1 -o - -L #{ROOT_KEYS_SCRIPT} | %s"
    APT_CFG = %q{ Acquire::http::Proxy "http://proxy.puppetlabs.net:3128/"; }
    IPS_PKG_REPO="http://solaris-11-internal-repo.delivery.puppetlabs.net"

    #Run timesync on the provided hosts
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def timesync host, opts
      logger = opts[:logger]
      ntp_server = opts[:ntp_server] ? opts[:ntp_server] : NTPSERVER
      block_on host do |host|
        logger.notify "Update system time sync for '#{host.name}'"
        if host['platform'].include? 'windows'
          # The exit code of 5 is for Windows 2008 systems where the w32tm /register command
          # is not actually necessary.
          host.exec(Command.new("w32tm /register"), :acceptable_exit_codes => [0,5])
          host.exec(Command.new("net start w32time"), :acceptable_exit_codes => [0,2])
          host.exec(Command.new("w32tm /config /manualpeerlist:#{ntp_server} /syncfromflags:manual /update"))
          host.exec(Command.new("w32tm /resync"))
          logger.notify "NTP date succeeded on #{host}"
        else
          case
            when host['platform'] =~ /sles-/
              ntp_command = "sntp #{ntp_server}"
            when host['platform'] =~ /cisco_nexus/
              ntp_server = host.exec(Command.new("getent hosts #{NTPSERVER} | head -n1 |cut -d \" \" -f1"), :acceptable_exit_codes => [0]).stdout
              ntp_command = "sudo -E sh -c 'export DCOS_CONTEXT=2;/isan/bin/ntpdate -u -t 20 #{ntp_server}'"
            else
              ntp_command = "ntpdate -u -t 20 #{ntp_server}"
          end
          success=false
          try = 0
          until try >= TRIES do
            try += 1
            if host.exec(Command.new(ntp_command), :accept_all_exit_codes => true).exit_code == 0
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
      nil
    rescue => e
      report_and_raise(logger, e, "timesync (--ntp)")
    end

    # Validate that hosts are prepared to be used as SUTs, if packages are missing attempt to
    # install them.
    #
    # Verifies the presence of #{HostPrebuiltSteps::UNIX_PACKAGES} on unix platform hosts,
    # {HostPrebuiltSteps::SLES_PACKAGES} on SUSE platform hosts,
    # {HostPrebuiltSteps::DEBIAN_PACKAGES} on debian platform hosts,
    # {HostPrebuiltSteps::CUMULUS_PACKAGES} on cumulus platform hosts,
    # {HostPrebuiltSteps::WINDOWS_PACKAGES} on cygwin-installed windows platform hosts,
    # and {HostPrebuiltSteps::PSWINDOWS_PACKAGES} on non-cygwin windows platform hosts.
    #
    # @param [Host, Array<Host>, String, Symbol] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def validate_host host, opts
      logger = opts[:logger]
      block_on host do |host|
        case
        when host['platform'] =~ /sles-10/
          check_and_install_packages_if_needed(host, SLES10_PACKAGES)
        when host['platform'] =~ /sles-/
          check_and_install_packages_if_needed(host, SLES_PACKAGES)
        when host['platform'] =~ /debian/
          check_and_install_packages_if_needed(host, DEBIAN_PACKAGES)
        when host['platform'] =~ /cumulus/
          check_and_install_packages_if_needed(host, CUMULUS_PACKAGES)
        when (host['platform'] =~ /windows/ and host.is_cygwin?)
          raise RuntimeError, "cygwin is not installed on #{host}" if !host.cygwin_installed?
          check_and_install_packages_if_needed(host, WINDOWS_PACKAGES)
        when (host['platform'] =~ /windows/ and not host.is_cygwin?)
          check_and_install_packages_if_needed(host, PSWINDOWS_PACKAGES)
        when host['platform'] =~ /freebsd/
          check_and_install_packages_if_needed(host, FREEBSD_PACKAGES)
        when host['platform'] =~ /openbsd/
          check_and_install_packages_if_needed(host, OPENBSD_PACKAGES)
        when host['platform'] =~ /solaris-10/
          check_and_install_packages_if_needed(host, SOLARIS10_PACKAGES)
        when host['platform'] =~ /solaris-1[1-9]/
          check_and_install_packages_if_needed(host, SOLARIS11_PACKAGES)
        when host['platform'] =~ /archlinux/
          check_and_install_packages_if_needed(host, ARCHLINUX_PACKAGES)
        when host['platform'] !~ /debian|aix|solaris|windows|sles-|osx-|cumulus|f5-|netscaler|cisco_/
          check_and_install_packages_if_needed(host, UNIX_PACKAGES)
        end
      end
    rescue => e
      report_and_raise(logger, e, "validate")
    end

    # Installs the given packages if they aren't already on a host
    #
    # @param [Host] host Host to act on
    # @param [Array<String>] package_list List of package names to install
    def check_and_install_packages_if_needed host, package_list
      package_list.each do |string|
        alternatives = string.split('|')
        next if alternatives.any? { |pkg| host.check_for_package pkg }
        install_one_of_packages host, alternatives
      end
    end

    # Installs one of alternative packages (first available)
    #
    # @param [Host] host Host to act on
    # @param [Array<String>] packages List of package names (alternatives).
    def install_one_of_packages host, packages
      error = nil
      packages.each do |pkg|
        begin
          return host.install_package pkg
        rescue Beaker::Host::CommandFailure => e
          error = e
        end
      end
      raise error
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
        if host['platform'] =~ /solaris|eos/
          host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "bash"), :accept_all_exit_codes => true)
        elsif host['platform'] =~ /aix/
          host.exec(Command.new(ROOT_KEYS_SYNC_CMD_AIX % "env PATH=/usr/gnu/bin:$PATH bash"), :accept_all_exit_codes => true)
        else
          host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "env PATH=\"/usr/gnu/bin:$PATH\" bash"), :accept_all_exit_codes => true)
        end
      end
    rescue => e
      report_and_raise(logger, e, "sync_root_keys")
    end

    # Run 'apt-get update' on the provided host or hosts.
    # If the platform of the provided host is not ubuntu, debian or cumulus: do nothing.
    #
    # @param [Host, Array<Host>] hosts One or more hosts to act upon
    def apt_get_update hosts
      block_on hosts do |host|
        if host[:platform] =~ /ubuntu|debian|cumulus/
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

    # On ubuntu, debian, or cumulus host or hosts: alter apt configuration to use
    # the internal Puppet Labs proxy {HostPrebuiltSteps::APT_CFG} proxy.
    # On solaris-11 host or hosts: alter pkg to point to
    # the internal Puppet Labs proxy {HostPrebuiltSteps::IPS_PKG_REPO}.
    #
    # Do nothing for other platform host or hosts.
    #
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def proxy_config( host, opts )
      logger = opts[:logger]
      block_on host do |host|
        case
        when host['platform'] =~ /ubuntu|debian|cumulus/
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

    #Install EPEL on host or hosts with platform = /el-(5|6|7)/.  Do nothing on host or hosts of other platforms.
    # @param [Host, Array<Host>] host One or more hosts to act upon.  Will use individual host epel_url, epel_arch
    #                                 and epel_pkg before using defaults provided in opts.
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Boolean] :debug If true, print verbose rpm information when installing EPEL
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    # @option opts [String] :epel_url Link to download from
    def add_el_extras( host, opts )
      #add_el_extras
      #only supports el-* platforms
      logger = opts[:logger]
      debug_opt = opts[:debug] ? 'vh' : ''
      block_on host do |host|
        case
        when el_based?(host) && ['5','6','7'].include?(host['platform'].version)
          result = host.exec(Command.new('rpm -qa | grep epel-release'), :acceptable_exit_codes => [0,1])
          if result.exit_code == 1
            url_base = opts[:epel_url]
            url_base = opts[:epel_url_archive] if host['platform'].version == '5'
            host.exec(Command.new("rpm -i#{debug_opt} #{url_base}/epel-release-latest-#{host['platform'].version}.noarch.rpm"))
            #update /etc/yum.repos.d/epel.repo for new baseurl
            host.exec(Command.new("sed -i -e 's;#baseurl.*$;baseurl=#{Regexp.escape("#{url_base}/#{host['platform'].version}")}/\$basearch;' /etc/yum.repos.d/epel.repo"))
            #remove mirrorlist
            host.exec(Command.new("sed -i -e '/mirrorlist/d' /etc/yum.repos.d/epel.repo"))
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
      if host['platform'] =~ /windows/
        if host.is_cygwin?
          resolv_conf = host.exec(Command.new("cat /cygdrive/c/Windows/System32/drivers/etc/hosts")).stdout
        else
          resolv_conf = host.exec(Command.new('type C:\Windows\System32\drivers\etc\hosts')).stdout
        end
      else
        resolv_conf = host.exec(Command.new("cat /etc/resolv.conf")).stdout
      end
      resolv_conf.each_line { |line|
        if line =~ /^\s*domain\s+(\S+)/
          domain = $1
        elsif line =~ /^\s*search\s+(\S+)/
          search = $1
        end
      }
      return_value ||= domain
      return_value ||= search

      if return_value
        return_value.gsub(/\.$/, '')
      end
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
      if host['platform'] =~ /freebsd/
        host.echo_to_file(etc_hosts, '/etc/hosts')
      elsif ((host['platform'] =~ /windows/) and not host.is_cygwin?)
        host.exec(Command.new("echo '#{etc_hosts}' >> C:\\Windows\\System32\\drivers\\etc\\hosts"))
      else
        host.exec(Command.new("echo '#{etc_hosts}' >> /etc/hosts"))
      end
      # AIX must be configured to prefer local DNS over external
      if host['platform'] =~ /aix/
        aix_netsvc = '/etc/netsvc.conf'
        aix_local_resolv = 'hosts = local, bind'
        unless host.exec(Command.new("grep '#{aix_local_resolv}' #{aix_netsvc}"), :accept_all_exit_codes => true).exit_code == 0
          host.exec(Command.new("echo '#{aix_local_resolv}' >> #{aix_netsvc}"))
        end
      end
    end

    #Make it possible to log in as root by copying the current users ssh keys to the root account
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def copy_ssh_to_root host, opts
      logger = opts[:logger]
      block_on host do |host|
        logger.debug "Give root a copy of current user's keys, on #{host.name}"
        if host['platform'] =~ /windows/ and host.is_cygwin?
          host.exec(Command.new('cp -r .ssh /cygdrive/c/Users/Administrator/.'))
          host.exec(Command.new('chown -R Administrator /cygdrive/c/Users/Administrator/.ssh'))
        elsif host['platform'] =~ /windows/ and not host.is_cygwin?
          # from https://www.microsoft.com/resources/documentation/windows/xp/all/proddocs/en-us/xcopy.mspx?mfr=true:
          #    /i : If Source is a directory or contains wildcards and Destination
          #      does not exist, xcopy assumes destination specifies a directory
          #      name and creates a new directory. Then, xcopy copies all specified
          #      files into the new directory. By default, xcopy prompts you to
          #      specify whether Destination is a file or a directory.
          #
          #    /y : Suppresses prompting to confirm that you want to overwrite an
          #      existing destination file.
          host.exec(Command.new("if exist .ssh (xcopy .ssh C:\\Users\\Administrator\\.ssh /s /e /y /i)"))
        elsif host['platform'] =~ /osx/
          host.exec(Command.new('sudo cp -r .ssh /var/root/.'), {:pty => true})
        elsif host['platform'] =~ /freebsd/
          host.exec(Command.new('sudo cp -r .ssh /root/.'), {:pty => true})
        elsif host['platform'] =~ /openbsd/
          host.exec(Command.new('sudo cp -r .ssh /root/.'), {:pty => true})
        elsif host['platform'] =~ /solaris-10/
          host.exec(Command.new('sudo cp -r .ssh /.'), {:pty => true})
        elsif host['platform'] =~ /solaris-11/
          host.exec(Command.new('sudo cp -r .ssh /root/.'), {:pty => true})
        else
          host.exec(Command.new('sudo su -c "cp -r .ssh /root/."'), {:pty => true})
        end

        if host.selinux_enabled?
          host.exec(Command.new('sudo fixfiles restore /root'))
        end
      end
    end

    # Update /etc/hosts to make it possible for each provided host to reach each other host by name.
    # Assumes that each provided host has host[:ip] set; in the instance where a provider sets
    # host['ip'] to an address which facilitates access to the host externally, but the actual host
    # addresses differ from this, we check first for the presence of a host['vm_ip'] key first,
    # and use that if present.
    # @param [Host, Array<Host>] hosts An array of hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def hack_etc_hosts hosts, opts
      etc_hosts = "127.0.0.1\tlocalhost localhost.localdomain\n"
      hosts.each do |host|
        ip = host['vm_ip'] || host['ip'].to_s
        hostname = host[:vmhostname] || host.name
        domain = get_domain_name(host)
        etc_hosts += "#{ip}\t#{hostname}.#{domain} #{hostname}\n"
      end
      hosts.each do |host|
        set_etc_hosts(host, etc_hosts)
      end
    end

    # Update /etc/hosts to make updates.puppetlabs.com (aka the dujour server) resolve to 127.0.01,
    # so that we don't pollute the server with test data.  See SERVER-1000, BKR-182, BKR-237, DJ-10
    # for additional details.
    def disable_updates hosts, opts
      logger = opts[:logger]
      hosts.each do |host|
        next if host['platform'] =~ /netscaler/
        logger.notify "Disabling updates.puppetlabs.com by modifying hosts file to resolve updates to 127.0.0.1 on #{host}"
        set_etc_hosts(host, "127.0.0.1\tupdates.puppetlabs.com\n")
      end
    end

    # Update sshd_config on debian, ubuntu, centos, el, redhat, cumulus, and fedora boxes to allow for root login
    #
    # Does nothing on other platfoms.
    #
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def enable_root_login host, opts
      logger = opts[:logger]
      block_on host do |host|
        logger.debug "Update sshd_config to allow root login"
        if host['platform'] =~ /osx/
          # If osx > 10.10 use '/private/etc/ssh/sshd_config', else use '/etc/sshd_config'
          ssh_config_file = '/private/etc/ssh/sshd_config'
          ssh_config_file = '/etc/sshd_config' if host['platform'] =~ /^osx-10\.(9|10)/i

          host.exec(Command.new("sudo sed -i '' 's/#PermitRootLogin no/PermitRootLogin Yes/g' #{ssh_config_file}"))
          host.exec(Command.new("sudo sed -i '' 's/#PermitRootLogin yes/PermitRootLogin Yes/g' #{ssh_config_file}"))
        elsif host['platform'] =~ /freebsd/
          host.exec(Command.new("sudo sed -i -e 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config"), {:pty => true} )
        elsif host['platform'] =~ /openbsd/
          host.exec(Command.new("sudo perl -pi -e 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config"), {:pty => true} )
        elsif host['platform'] =~ /solaris-10/
          host.exec(Command.new("sudo gsed -i -e 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config"), {:pty => true} )
        elsif host['platform'] =~ /solaris-11/
          host.exec(Command.new("if grep \"root::::type=role\" /etc/user_attr; then sudo rolemod -K type=normal root; else echo \"root user already type=normal\"; fi"), {:pty => true} )
          host.exec(Command.new("sudo gsed -i -e 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config"), {:pty => true} )
        elsif host.is_cygwin?
          host.exec(Command.new("sed -ri 's/^#?PermitRootLogin /PermitRootLogin yes/' /etc/sshd_config"), {:pty => true})
        elsif host.is_powershell?
          logger.warn("Attempting to enable root login non-supported platform: #{host.name}: #{host['platform']}")
        else
          host.exec(Command.new("sudo su -c \"sed -ri 's/^#?PermitRootLogin no|^#?PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config\""), {:pty => true})
        end
        #restart sshd
        if host['platform'] =~ /debian|ubuntu|cumulus/
          host.exec(Command.new("sudo su -c \"service ssh restart\""), {:pty => true})
        elsif host['platform'] =~ /arch|centos-7|el-7|redhat-7|fedora-(1[4-9]|2[0-9])/
          host.exec(Command.new("sudo -E systemctl restart sshd.service"), {:pty => true})
        elsif host['platform'] =~ /centos|el-|redhat|fedora|eos/
          host.exec(Command.new("sudo -E /sbin/service sshd reload"), {:pty => true})
        elsif host['platform'] =~ /(free|open)bsd/
          host.exec(Command.new("sudo /etc/rc.d/sshd restart"))
        elsif host['platform'] =~ /solaris/
          host.exec(Command.new("sudo -E svcadm restart network/ssh"), {:pty => true} )
        else
          logger.warn("Attempting to update ssh on non-supported platform: #{host.name}: #{host['platform']}")
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
        if host['platform'] =~ /centos|el-|redhat|fedora|eos/
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
        if host['platform'] =~ /centos|el-|redhat|fedora|eos/
          logger.debug("Disabling iptables on #{host.name}")
          host.exec(Command.new("sudo su -c \"/etc/init.d/iptables stop\""), {:pty => true})
        else
          logger.warn("Attempting to disable iptables on non-supported platform: #{host.name}: #{host['platform']}")
        end
      end
    end

    # Setup files for enabling requests to pass to a proxy server
    # This works for the APT package manager on debian, ubuntu, and cumulus
    # and YUM package manager on el, centos, fedora and redhat.
    # @param [Host, Array<Host>, String, Symbol] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def package_proxy host, opts
      logger = opts[:logger]

      block_on host do |host|
        logger.debug("enabling proxy support on #{host.name}")
        case host['platform']
          when /ubuntu/, /debian/, /cumulus/
            host.exec(Command.new("echo 'Acquire::http::Proxy \"#{opts[:package_proxy]}/\";' >> /etc/apt/apt.conf.d/10proxy"))
          when /^el-/, /centos/, /fedora/, /redhat/, /eos/
            host.exec(Command.new("echo 'proxy=#{opts[:package_proxy]}/' >> /etc/yum.conf"))
        else
          logger.debug("Attempting to enable package manager proxy support on non-supported platform: #{host.name}: #{host['platform']}")
        end
      end
    end


    # Merge the two provided hashes so that an array of values is created from collisions
    # @param [Hash] h1 The first hash
    # @param [Hash] h2 The second hash
    # @return [Hash] A merged hash with arrays of values where collisions between the two hashes occured.
    # @example
    #   > h1 = {:PATH=>"/1st/path"}
    #   > h2 = {:PATH=>"/2nd/path"}
    #   > additive_hash_merge(h1, h2)
    #   => {:PATH=>["/1st/path", "/2nd/path"]}
    def additive_hash_merge h1, h2
      merged_hash = {}
      normalized_h2 = h2.inject({}) { |h, (k, v)| h[k.to_s.upcase] = v; h }
      h1.each_pair do |key, val|
        normalized_key = key.to_s.upcase
        if normalized_h2.has_key?(normalized_key)
          merged_hash[key] = [h1[key], normalized_h2[normalized_key]]
          merged_hash[key] = merged_hash[key].uniq #remove dupes
        end
      end
      merged_hash
    end

    # Create the hash of default environment from host (:host_env), global options hash (:host_env) and default PE/Foss puppet variables
    # @param [Host] host The host to construct the environment hash for, host specific environment should be in :host_env in a hash
    # @param [Hash] opts Hash of options, including optional global  host_env to be applied to each provided host
    # @return [Hash] A hash of environment variables for provided host
    def construct_env host, opts
      env = additive_hash_merge(host[:host_env], opts[:host_env])

      env.each_key do |key|
        separator = host['pathseparator']
        if key == 'PATH' && (not host.is_powershell?)
          separator = ':'
        end
        env[key] = env[key].join(separator)
      end
      env
    end

    # Add a host specific set of env vars to each provided host's ~/.ssh/environment
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    def set_env host, opts
      logger = opts[:logger]

      block_on host do |host|
        skip_msg = host.skip_set_env?
        unless skip_msg.nil?
          logger.debug( skip_msg )
          next
        end

        env = construct_env(host, opts)
        logger.debug("setting local environment on #{host.name}")
        if host['platform'] =~ /windows/ and host.is_cygwin?
          env['CYGWIN'] = 'nodosfilewarning'
        end
        host.ssh_permit_user_environment()

        host.ssh_set_user_environment(env)

        # REMOVE POST BEAKER 3: backwards compatability, do some setup based upon the global type
        # this is the worst and i hate it
        Class.new.extend(Beaker::DSL).configure_type_defaults_on(host)

        #close the host to re-establish the connection with the new sshd settings
        host.close

        # print out the working env
        if host.is_powershell?
          host.exec(Command.new("SET"))
        else
          host.exec(Command.new("cat #{host[:ssh_env_file]}"))
        end

      end
    end

    private

    # A helper to tell whether a host is el-based
    # @param [Host] host the host to act upon
    #
    # @return [Boolean] if the host is el_based
    def el_based? host
      ['centos','redhat','scientific','el','oracle'].include?(host['platform'].variant)
    end

  end

end
