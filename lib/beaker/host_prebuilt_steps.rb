%w[command dsl].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  # Provides convienience methods for commonly run actions on hosts
  module HostPrebuiltSteps
    include Beaker::DSL::Patterns

    NTPSERVER = 'pool.ntp.org'
    SLEEPWAIT = 5
    TRIES = 5
    ETC_HOSTS_PATH = "/etc/hosts"
    ETC_HOSTS_PATH_SOLARIS = "/etc/inet/hosts"

    # Run timesync on the provided hosts
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
          host.exec(Command.new("w32tm /register"), :acceptable_exit_codes => [0, 5])
          host.exec(Command.new("net start w32time"), :acceptable_exit_codes => [0, 2])
          host.exec(Command.new("w32tm /config /manualpeerlist:#{ntp_server} /syncfromflags:manual /update"))
          host.exec(Command.new("w32tm /resync"))
          logger.notify "NTP date succeeded on #{host}"
        else
          if host['platform'].uses_chrony?
            ntp_command = "chronyc add server #{ntp_server} prefer trust;chronyc makestep;chronyc burst 1/2"
          elsif /opensuse-|sles-/.match?(host['platform'])
            ntp_command = "sntp #{ntp_server}"
          else
            ntp_command = "ntpdate -u -t 20 #{ntp_server}"
          end
          success = false
          try = 0
          until try >= TRIES
            try += 1
            if host.exec(Command.new(ntp_command), :accept_all_exit_codes => true).exit_code == 0
              success = true
              break
            end
            sleep SLEEPWAIT
          end
          raise "NTP date was not successful after #{try} tries" unless success

          logger.notify "NTP date succeeded on #{host} after #{try} tries"

        end
      end
      nil
    rescue => e
      report_and_raise(logger, e, "timesync (--ntp)")
    end

    # Validate that hosts are prepared to be used as SUTs, if packages are missing attempt to
    # install them.
    #
    # @param [Host, Array<Host>, String, Symbol] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def validate_host host, opts
      logger = opts[:logger]
      block_on host do |host|
        check_and_install_packages_if_needed(host, host_packages(host))
      end
    rescue => e
      report_and_raise(logger, e, "validate")
    end

    # Return a list of packages that should be present.
    #
    # @param [Host] host A host return the packages for
    # @return [Array<String>] A list of packages to install
    def host_packages(host)
      packages = host['platform'].base_packages
      if host.is_cygwin?
        raise RuntimeError, "cygwin is not installed on #{host}" if !host.cygwin_installed?

        packages << 'curl'
      end
      packages += host['platform'].timesync_packages if host[:timesync]
      packages
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

    # Run 'apt-get update' on the provided host or hosts.
    # If the platform of the provided host is not ubuntu or debian: do nothing.
    #
    # @param [Host, Array<Host>] hosts One or more hosts to act upon
    def apt_get_update hosts
      block_on hosts do |host|
        # -qq: Only output errors to stdout
        host.exec(Command.new("apt-get update -qq")) if /ubuntu|debian/.match?(host[:platform])
      end
    end

    # Create a file on host or hosts at the provided file path with the provided file contents.
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [String] file_path The path at which the new file will be created on the host or hosts.
    # @param [String] file_content The contents of the file to be created on the host or hosts.
    def copy_file_to_remote(host, file_path, file_content)
      block_on host do |host|
        Tempfile.open 'beaker' do |tempfile|
          File.open(tempfile.path, 'w') { |file| file.puts file_content }

          host.do_scp_to(tempfile.path, file_path, @options)
        end
      end
    end

    # Determine the domain name of the provided host from its /etc/resolv.conf
    # @param [Host] host the host to act upon
    def get_domain_name(host)
      domain = nil
      search = nil
      resolv_conf = if host['platform'].include?('windows')
                      if host.is_cygwin?
                        host.exec(Command.new("cat /cygdrive/c/Windows/System32/drivers/etc/hosts")).stdout
                      else
                        host.exec(Command.new('type C:\Windows\System32\drivers\etc\hosts')).stdout
                      end
                    else
                      host.exec(Command.new("cat /etc/resolv.conf")).stdout
                    end
      resolv_conf.each_line do |line|
        if (match = /^\s*domain\s+(\S+)/.match(line))
          domain = match[1]
        elsif (match = /^\s*search\s+(\S+)/.match(line))
          search = match[1]
        end
      end
      return_value ||= domain
      return_value ||= search

      return unless return_value

      return_value.gsub(/\.$/, '')
    end

    # Append the provided string to the /etc/hosts file of the provided host
    # @param [Host] host the host to act upon
    # @param [String] etc_hosts The string to append to the /etc/hosts file
    def set_etc_hosts(host, etc_hosts)
      if host['platform'].include?('freebsd')
        host.echo_to_file(etc_hosts, '/etc/hosts')
      elsif ((host['platform'].include?('windows')) and not host.is_cygwin?)
        host.exec(Command.new("echo '#{etc_hosts}' >> C:\\Windows\\System32\\drivers\\etc\\hosts"))
      else
        host.exec(Command.new("echo '#{etc_hosts}' >> /etc/hosts"))
      end
      # AIX must be configured to prefer local DNS over external
      return unless host['platform'].include?('aix')

      aix_netsvc = '/etc/netsvc.conf'
      aix_local_resolv = 'hosts = local, bind'
      return if host.exec(Command.new("grep '#{aix_local_resolv}' #{aix_netsvc}"), :accept_all_exit_codes => true).exit_code == 0

      host.exec(Command.new("echo '#{aix_local_resolv}' >> #{aix_netsvc}"))
    end

    # Make it possible to log in as root by copying the current users ssh keys to the root account
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def copy_ssh_to_root host, opts
      logger = opts[:logger]
      block_on host do |host|
        logger.debug "Give root a copy of current user's keys, on #{host.name}"
        if host['platform'].include?('windows') and host.is_cygwin?
          host.exec(Command.new('cp -r .ssh /cygdrive/c/Users/Administrator/.'))
          host.exec(Command.new('chown -R Administrator /cygdrive/c/Users/Administrator/.ssh'))
        elsif host['platform'].include?('windows') and not host.is_cygwin?
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
        elsif host['platform'].include?('osx')
          host.exec(Command.new('sudo cp -r .ssh /var/root/.'), { :pty => true })
        elsif /(free|open)bsd/.match?(host['platform']) || host['platform'].include?('solaris-11')
          host.exec(Command.new('sudo cp -r .ssh /root/.'), { :pty => true })
        elsif host['platform'].include?('solaris-10')
          host.exec(Command.new('sudo cp -r .ssh /.'), { :pty => true })
        else
          host.exec(Command.new('sudo su -c "cp -r .ssh /root/."'), { :pty => true })
        end

        host.exec(Command.new('sudo fixfiles restore /root')) if host.selinux_enabled?
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
    def hack_etc_hosts hosts, _opts
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
        logger.notify "Disabling updates.puppetlabs.com by modifying hosts file to resolve updates to 127.0.0.1 on #{host}"
        set_etc_hosts(host, "127.0.0.1\tupdates.puppetlabs.com\n")
      end
    end

    # Update sshd_config on debian, ubuntu, centos, el, redhat and fedora boxes to allow for root login
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
        if host['platform'].include?('osx')
          # If osx > 10.10 use '/private/etc/ssh/sshd_config', else use '/etc/sshd_config'
          ssh_config_file = '/private/etc/ssh/sshd_config'
          ssh_config_file = '/etc/sshd_config' if /^osx-10\.(9|10)/i.match?(host['platform'])

          host.exec(Command.new("sudo sed -i '' 's/#PermitRootLogin no/PermitRootLogin Yes/g' #{ssh_config_file}"))
          host.exec(Command.new("sudo sed -i '' 's/#PermitRootLogin yes/PermitRootLogin Yes/g' #{ssh_config_file}"))
        elsif host['platform'].include?('freebsd')
          host.exec(Command.new("sudo sed -i -e 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config"), { :pty => true })
        elsif host['platform'].include?('openbsd')
          host.exec(Command.new("sudo perl -pi -e 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config"), { :pty => true })
        elsif host['platform'].include?('solaris-10')
          host.exec(Command.new("sudo gsed -i -e 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config"), { :pty => true })
        elsif host['platform'].include?('solaris-11')
          host.exec(Command.new("if grep \"root::::type=role\" /etc/user_attr; then sudo rolemod -K type=normal root; else echo \"root user already type=normal\"; fi"), { :pty => true })
          host.exec(Command.new("sudo gsed -i -e 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config"), { :pty => true })
        elsif host.is_powershell?
          logger.warn("Attempting to enable root login non-supported platform: #{host.name}: #{host['platform']}")
        elsif host.is_cygwin?
          host.exec(Command.new("sed -ri 's/^#?PermitRootLogin /PermitRootLogin yes/' /etc/sshd_config"), { :pty => true })
        else
          host.exec(Command.new("sudo su -c \"sed -ri 's/^#?PermitRootLogin no|^#?PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config\""), { :pty => true })
        end
        # restart sshd
        if /debian|ubuntu/.match?(host['platform'])
          host.exec(Command.new("sudo su -c \"service ssh restart\""), { :pty => true })
        elsif /(el|centos|redhat|oracle|scientific)-[0-6]\b/.match?(host['platform'])
          host.exec(Command.new("sudo -E /sbin/service sshd reload"), { :pty => true })
        elsif /amazon|arch|centos|el|redhat|fedora/.match?(host['platform'])
          host.exec(Command.new("sudo -E systemctl restart sshd.service"), { :pty => true })
        elsif /(free|open)bsd/.match?(host['platform'])
          host.exec(Command.new("sudo /etc/rc.d/sshd restart"))
        elsif host['platform'].include?('solaris')
          host.exec(Command.new("sudo -E svcadm restart network/ssh"), { :pty => true })
        else
          logger.warn("Attempting to update ssh on non-supported platform: #{host.name}: #{host['platform']}")
        end
      end
    end

    # Disable SELinux on centos, does nothing on other platforms
    # @param [Host, Array<Host>] host One or more hosts to act upon
    # @param [Hash{Symbol=>String}] opts Options to alter execution.
    # @option opts [Beaker::Logger] :logger A {Beaker::Logger} object
    def disable_se_linux host, opts
      logger = opts[:logger]
      block_on host do |host|
        if /centos|el-|redhat|fedora/.match?(host['platform'])
          logger.debug("Disabling se_linux on #{host.name}")
          host.exec(Command.new("sudo su -c \"setenforce 0\""), { :pty => true })
        else
          logger.warn("Attempting to disable SELinux on non-supported platform: #{host.name}: #{host['platform']}")
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
        when /amazon/, /^el-/, /centos/, /fedora/, /redhat/
          host.exec(Command.new("echo 'proxy=#{opts[:package_proxy]}/' >> /etc/yum.conf"))
        when /solaris-11/
          host.exec(Command.new("/usr/bin/pkg unset-publisher solaris || :"))
          host.exec(Command.new("/usr/bin/pkg set-publisher -g %s solaris" % opts[:package_proxy]))
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
      normalized_h2 = h2.each_with_object({}) { |(k, v), h| h[k.to_s.upcase] = v; }
      h1.each_pair do |key, _val|
        normalized_key = key.to_s.upcase
        if normalized_h2.has_key?(normalized_key)
          merged_hash[key] = [h1[key], normalized_h2[normalized_key]]
          merged_hash[key] = merged_hash[key].uniq # remove dupes
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
        separator = ':' if key == 'PATH' && (not host.is_powershell?)
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
          logger.debug(skip_msg)
          next
        end

        env = construct_env(host, opts)

        logger.debug("setting local environment on #{host.name}")

        env['CYGWIN'] = 'nodosfilewarning' if host['platform'].include?('windows') && host.is_cygwin?

        host.ssh_permit_user_environment
        host.ssh_set_user_environment(env)

        # close the host to re-establish the connection with the new sshd settings
        host.close

        # print out the working env
        if host.is_powershell?
          host.exec(Command.new("SET"))
        else
          host.exec(Command.new("cat #{host[:ssh_env_file]}"))
        end
      end
    end
  end
end
