require 'pathname'

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
    CUMULUS_PACKAGES = ['addons', 'ntpdate', 'lsb-release']
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
            else
              ntp_command = "ntpdate -t 20 #{ntp_server}"
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

    # Validate that hosts are prepared to be used as SUTs, if packages are missing attempt to
    # install them.
    #
    # Verifies the presence of #{HostPrebuiltSteps::UNIX_PACKAGES} on unix platform hosts,
    # {HostPrebuiltSteps::SLES_PACKAGES} on SUSE platform hosts,
    # {HostPrebuiltSteps::DEBIAN_PACKAGES} on debian platform hosts,
    # {HostPrebuiltSteps::CUMULUS_PACKAGES} on cumulus platform hosts,
    # and {HostPrebuiltSteps::WINDOWS_PACKAGES} on windows platform hosts.
    #
    # @param [Host, Array<Host>, String, Symbol] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def validate_host host, opts
      logger = opts[:logger]
      block_on host do |host|
        case
        when host['platform'] =~ /sles-/
          check_and_install_packages_if_needed(host, SLES_PACKAGES)
        when host['platform'] =~ /debian/
          check_and_install_packages_if_needed(host, DEBIAN_PACKAGES)
        when host['platform'] =~ /cumulus/
          check_and_install_packages_if_needed(host, CUMULUS_PACKAGES)
        when host['platform'] =~ /windows/
          check_and_install_packages_if_needed(host, WINDOWS_PACKAGES)
        when host['platform'] !~ /debian|aix|solaris|windows|sles-|osx-|cumulus/
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
      package_list.each do |pkg|
        if not host.check_for_package pkg
          host.install_package pkg
        end
      end
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
          host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "bash"), :acceptable_exit_codes => (0..255))
        else
          host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "env PATH=/usr/gnu/bin:$PATH bash"), :acceptable_exit_codes => (0..255))
        end
      end
    rescue => e
      report_and_raise(logger, e, "sync_root_keys")
    end

    #Determine the Extra Packages for Enterprise Linux URL for the provided Enterprise Linux host.
    # @param [Host, Array<Host>] host One host to act on.  Will use host epel_url, epel_arch and epel_pkg
    #                                 before using defaults provided in opts.
    # @return [String, String, String] The URL, arch  and package name for EPL for the provided host
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [String] :epel_url Link to download
    # @option opts [String] :epel_arch Architecture to download (i386, x86_64, etc), defaults to i386
    # @option opts [String] :epel_6_pkg Package to download from provided link for el-6
    # @option opts [String] :epel_5_pkg Package to download from provided link for el-5
    # @raise [Exception] Raises an error if the host provided's platform != /el-(5|6)/
    def epel_info_for host, opts
      if !el_based?(host)
        raise "epel_info_for! not available for #{host.name} on platform #{host['platform']}"
      end

      version = host['platform'].version
      if version == '6'
        url = "#{host[:epel_url] || opts[:epel_url]}/#{version}"
        pkg = host[:epel_pkg] || opts[:epel_6_pkg]
      elsif version == '5'
        url = "#{host[:epel_url] || opts[:epel_url]}/#{version}"
        pkg = host[:epel_pkg] || opts[:epel_5_pkg]
      else
        raise "epel_info_for does not support el version #{version}, on #{host.name}"
      end
      return url, host[:epel_arch] || opts[:epel_arch] || 'i386', pkg
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

    #Install EPEL on host or hosts with platform = /el-(5|6)/.  Do nothing on host or hosts of other platforms.
    # @param [Host, Array<Host>] host One or more hosts to act upon.  Will use individual host epel_url, epel_arch
    #                                 and epel_pkg before using defaults provided in opts.
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Boolean] :debug If true, print verbose rpm information when installing EPEL
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    # @option opts [String] :epel_url Link to download from 
    # @option opts [String] :epel_arch Architecture of epel to download (i386, x86_64, etc)
    # @option opts [String] :epel_6_pkg Package to download from provided link for el-6
    # @option opts [String] :epel_5_pkg Package to download from provided link for el-5
    def add_el_extras( host, opts )
      #add_el_extras
      #only supports el-* platforms
      logger = opts[:logger]
      debug_opt = opts[:debug] ? 'vh' : ''
      block_on host do |host|
        case
        when el_based?(host) && ['5','6'].include?(host['platform'].version)
          result = host.exec(Command.new('rpm -qa | grep epel-release'), :acceptable_exit_codes => [0,1])
          if result.exit_code == 1
            url, arch, pkg = epel_info_for host, opts
            host.exec(Command.new("rpm -i#{debug_opt} #{url}/#{arch}/#{pkg}"))
            #update /etc/yum.repos.d/epel.repo for new baseurl
            host.exec(Command.new("sed -i -e 's;#baseurl.*$;baseurl=#{Regexp.escape(url)}/\$basearch;' /etc/yum.repos.d/epel.repo"))
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
        logger.debug "Update /etc/ssh/sshd_config to allow root login"
        # note: this sed command only works on gnu sed
        host.exec(Command.new("sudo su -c \"sed -ri 's/^#?PermitRootLogin no|^#?PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config\""), {:pty => true}
        )
        #restart sshd
        if host['platform'] =~ /debian|ubuntu|cumulus/
          host.exec(Command.new("sudo su -c \"service ssh restart\""), {:pty => true})
        elsif host['platform'] =~ /centos|el-|redhat|fedora|eos/
          host.exec(Command.new("sudo -E /sbin/service sshd restart"))
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

    # 'echo' the provided value on the given host
    # @param [Host] host The host to execute the 'echo' on
    # @param [String] val The string to 'echo' on the host
    def echo_on_host host, val
      #val = val.gsub(/"/, "\"").gsub(/\(/, "\(")
      host.exec(Command.new("echo \"#{val}\"")).stdout.chomp
    end

    # Create the hash of default environment from host (:host_env), global options hash (:host_env) and default PE/Foss puppet variables
    # @param [Host] host The host to construct the environment hash for, host specific environment should be in :host_env in a hash
    # @param [Hash] opts Hash of options, including optional global  host_env to be applied to each provided host
    # @return [Hash] A hash of environment variables for provided host
    def construct_env host, opts
      env = additive_hash_merge(host[:host_env], opts[:host_env])

      #Add PATH and RUBYLIB

      #prepend any PATH already set for this host

      env['PATH'] = (%w(puppetbindir facterbindir hierabindir) << env['PATH']).compact.reject(&:empty?)
      #get the PATH defaults
      env['PATH'].map! { |val| host[val] }
      env['PATH'] = env['PATH'].compact.reject(&:empty?)
      #run the paths through echo to see if they have any subcommands that need processing
      env['PATH'].map! { |val| echo_on_host(host, val) }

      #prepend any RUBYLIB already set for this host
      env['RUBYLIB'] =  (%w(hieralibdir hierapuppetlibdir pluginlibpath puppetlibdir facterlibdir) << env['RUBYLIB']).compact.reject(&:empty?)
      #get the RUBYLIB defaults
      env['RUBYLIB'].map! { |val| host[val] }
      env['RUBYLIB'] = env['RUBYLIB'].compact.reject(&:empty?)
      #run the paths through echo to see if they have any subcommands that need processing
      env['RUBYLIB'].map! { |val| echo_on_host(host, val) }

      env.each_key do |key|
        env[key] = env[key].join(':')
      end
      env
    end

    # Add a host specific set of env vars to each provided host's ~/.ssh/environment
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    def set_env host, opts
      logger = opts[:logger]

      block_on host do |host|
        env = construct_env(host, opts)
        logger.debug("setting local environment on #{host.name}")
        case host['platform']
        when /windows/
          host.exec(Command.new("echo '\nPermitUserEnvironment yes' >> /etc/sshd_config"))
          host.exec(Command.new("cygrunsrv -E sshd"))
          host.exec(Command.new("cygrunsrv -S sshd"))
          env['CYGWIN'] = 'nodosfilewarning'
        when /osx/
          host.exec(Command.new("echo '\nPermitUserEnvironment yes' >> /etc/sshd_config"))
          host.exec(Command.new("launchctl unload /System/Library/LaunchDaemons/ssh.plist"))
          host.exec(Command.new("launchctl load /System/Library/LaunchDaemons/ssh.plist"))
        when /debian|ubuntu|cumulus/
          host.exec(Command.new("echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config"))
          host.exec(Command.new("service ssh restart"))
        when /el-|centos|fedora|redhat|oracle|scientific|eos/
          host.exec(Command.new("echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config"))
          host.exec(Command.new("/sbin/service sshd restart"))
        when /sles/
          host.exec(Command.new("echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config"))
          host.exec(Command.new("rcsshd restart"))
        when /solaris/
          host.exec(Command.new("echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config"))
          host.exec(Command.new("svcadm restart svc:/network/ssh:default"))
        when /aix/
          host.exec(Command.new("echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config"))
          host.exec(Command.new("stopsrc -g ssh"))
          host.exec(Command.new("startsrc -g ssh"))
        end

        #ensure that ~/.ssh/environment exists
        host.exec(Command.new("mkdir -p #{Pathname.new(host[:ssh_env_file]).dirname}"))
        host.exec(Command.new("chmod 0600 #{Pathname.new(host[:ssh_env_file]).dirname}"))
        host.exec(Command.new("touch #{host[:ssh_env_file]}"))

        #add the constructed env vars to this host
        host.add_env_var('RUBYLIB', '$RUBYLIB')
        host.add_env_var('PATH', '$PATH')
        env.each_pair do |var, value|
          host.add_env_var(var, value)
        end

        #close the host to re-establish the connection with the new sshd settings
        host.close
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
