module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains methods useful for Windows installs
      #
      module WindowsUtils
        # Given a host, returns it's system TEMP path
        #
        # @param [Host] host An object implementing {Beaker::Hosts}'s interface.
        #
        # @return [String] system temp path
        def get_system_temp_path(host)
          host.system_temp_path
        end
        alias_method :get_temp_path, :get_system_temp_path

        # Generates commands to be inserted into a Windows batch file to launch an MSI install
        # @param [String] msi_path The path of the MSI - can be a local Windows style file path like
        #                   c:\temp\puppet.msi OR a url like https://download.com/puppet.msi or file://c:\temp\puppet.msi
        # @param  [Hash{String=>String}] msi_opts MSI installer options
        #                   See https://docs.puppetlabs.com/guides/install_puppet/install_windows.html#msi-properties
        # @param [String] log_path The path to write the MSI log - must be a local Windows style file path
        #
        # @api private
        def msi_install_script(msi_path, msi_opts, log_path)
          # msiexec requires backslashes in file paths launched under cmd.exe start /w
          url_pattern = /^(https?|file):\/\//
          msi_path = msi_path.gsub(/\//, "\\") if msi_path !~ url_pattern

          msi_params = msi_opts.map{|k, v| "#{k}=#{v}"}.join(' ')

          # msiexec requires quotes around paths with backslashes - c:\ or file://c:\
          # not strictly needed for http:// but it simplifies this code
          batch_contents = <<-BATCH
start /w msiexec.exe /i \"#{msi_path}\" /qn /L*V #{log_path} #{msi_params}
exit /B %errorlevel%
          BATCH
        end

        # Given a host, path to MSI and MSI options, will create a batch file
        #   on the host, returning the path to the randomized batch file and
        #   the randomized log file
        #
        # @param [Host] host An object implementing {Beaker::Hosts}'s interface.
        # @param [String] msi_path The path of the MSI - can be a local Windows
        #   style file path like c:\temp\puppet.msi OR a url like
        #   https://download.com/puppet.msi or file://c:\temp\puppet.msi
        # @param  [Hash{String=>String}] msi_opts MSI installer options
        #   See https://docs.puppetlabs.com/guides/install_puppet/install_windows.html#msi-properties
        #
        # @api private
        # @return [String, String] path to the batch file, patch to the log file
        def create_install_msi_batch_on(host, msi_path, msi_opts)
          timestamp = Time.new.strftime('%Y-%m-%d_%H.%M.%S')
          tmp_path = host.system_temp_path
          tmp_path.gsub!('/', '\\')

          batch_name = "install-puppet-msi-#{timestamp}.bat"
          batch_path = "#{tmp_path}#{host.scp_separator}#{batch_name}"
          log_path = "#{tmp_path}\\install-puppet-#{timestamp}.log"

          Tempfile.open(batch_name) do |tmp_file|
            batch_contents = msi_install_script(msi_path, msi_opts, log_path)

            File.open(tmp_file.path, 'w') { |file| file.puts(batch_contents) }
            host.do_scp_to(tmp_file.path, batch_path, {})
          end

          return batch_path, log_path
        end

        # Given hosts construct a PATH that includes puppetbindir, facterbindir and hierabindir
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String] msi_path The path of the MSI - can be a local Windows style file path like
        #                   c:\temp\puppet.msi OR a url like https://download.com/puppet.msi or file://c:\temp\puppet.msi
        # @param  [Hash{String=>String}] msi_opts MSI installer options
        #                   See https://docs.puppetlabs.com/guides/install_puppet/install_windows.html#msi-properties
        # @option msi_opts [String] INSTALLIDIR Where Puppet and its dependencies should be installed.
        #                  (Defaults vary based on operating system and intaller architecture)
        #                  Requires Puppet 2.7.12 / PE 2.5.0
        # @option msi_opts [String] PUPPET_MASTER_SERVER The hostname where the puppet master server can be reached.
        #                  (Defaults to puppet)
        #                  Requires Puppet 2.7.12 / PE 2.5.0
        # @option msi_opts [String] PUPPET_CA_SERVER The hostname where the CA puppet master server can be reached, if you are using multiple masters and only one of them is acting as the CA.
        #                  (Defaults the value of PUPPET_MASTER_SERVER)
        #                  Requires Puppet 2.7.12 / PE 2.5.0
        # @option msi_opts [String] PUPPET_AGENT_CERTNAME The node’s certificate name, and the name it uses when requesting catalogs. This will set a value for
        #                  (Defaults to the node's fqdn as discovered by facter fqdn)
        #                  Requires Puppet 2.7.12 / PE 2.5.0
        # @option msi_opts [String] PUPPET_AGENT_ENVIRONMENT The node’s environment.
        #                  (Defaults to production)
        #                  Requires Puppet 3.3.1 / PE 3.1.0
        # @option msi_opts [String] PUPPET_AGENT_STARTUP_MODE Whether the puppet agent service should run (or be allowed to run)
        #                  (Defaults to Manual - valid values are Automatic, Manual or Disabled)
        #                  Requires Puppet 3.4.0 / PE 3.2.0
        # @option msi_opts [String] PUPPET_AGENT_ACCOUNT_USER Whether the puppet agent service should run (or be allowed to run)
        #                  (Defaults to LocalSystem)
        #                  Requires Puppet 3.4.0 / PE 3.2.0
        # @option msi_opts [String] PUPPET_AGENT_ACCOUNT_PASSWORD The password to use for puppet agent’s user account
        #                  (No default)
        #                  Requires Puppet 3.4.0 / PE 3.2.0
        # @option msi_opts [String] PUPPET_AGENT_ACCOUNT_DOMAIN The domain of puppet agent’s user account.
        #                  (Defaults to .)
        #                  Requires Puppet 3.4.0 / PE 3.2.0
        # @option opts [Boolean] :debug output the MSI installation log when set to true
        #                 otherwise do not output log (false; default behavior)
        #
        # @example
        #  install_msi_on(hosts, 'c:\puppet.msi', {:debug => true})
        #
        # @api private
        def install_msi_on(hosts, msi_path, msi_opts = {}, opts = {})
          block_on hosts do | host |
            msi_opts['PUPPET_AGENT_STARTUP_MODE'] ||= 'Manual'
            batch_path, log_file = create_install_msi_batch_on(host, msi_path, msi_opts)

            # begin / rescue here so that we can reuse existing error msg propagation
            begin
              # 1641 = ERROR_SUCCESS_REBOOT_INITIATED
              # 3010 = ERROR_SUCCESS_REBOOT_REQUIRED
              on host, Command.new("\"#{batch_path}\"", [], { :cmdexe => true }), :acceptable_exit_codes => [0, 1641, 3010]
            rescue
              on host, Command.new("type \"#{log_file}\"", [], { :cmdexe => true })
              raise
            end

            if opts[:debug]
              on host, Command.new("type \"#{log_file}\"", [], { :cmdexe => true })
            end

            if !host.is_cygwin?
              # HACK: for some reason, post install we need to refresh the connection to make puppet available for execution
              host.close
            end

            # verify service status post install
            # if puppet service exists, then pe-puppet is not queried
            # if puppet service does not exist, pe-puppet is queried and that exit code is used
            # therefore, this command will always exit 0 if either service is installed
            on host, Command.new("sc query puppet || sc query pe-puppet", [], { :cmdexe => true })
          end
        end

      end
    end
  end
end
