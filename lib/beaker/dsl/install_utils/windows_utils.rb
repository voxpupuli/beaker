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
            #
            # We also take advantage of this output to verify the startup
            # settings are honored as supplied to the MSI
            on host, Command.new("sc qc puppet || sc qc pe-puppet", [], { :cmdexe => true }) do |result|
              output = result.stdout
              startup_mode = msi_opts['PUPPET_AGENT_STARTUP_MODE'].upcase

              search = case startup_mode
                when 'AUTOMATIC'
                  { :code => 2, :name => 'AUTO_START' }
                when 'MANUAL'
                  { :code => 3, :name => 'DEMAND_START' }
                when 'DISABLED'
                  { :code => 4, :name => 'DISABLED' }
                end

              if output !~ /^\s+START_TYPE\s+:\s+#{search[:code]}\s+#{search[:name]}/
                raise "puppet service startup mode did not match supplied MSI option '#{startup_mode}'"
              end
            end

            # (PA-514) value for PUPPET_AGENT_STARTUP_MODE should be present in
            # registry and honored after install/upgrade.
            reg_key = host.is_x86_64? ? "HKLM\\SOFTWARE\\Wow6432Node\\Puppet Labs\\PuppetInstaller" :
                                        "HKLM\\SOFTWARE\\Puppet Labs\\PuppetInstaller"
            reg_query_command = %Q(reg query "#{reg_key}" /v "RememberedPuppetAgentStartupMode" | findstr #{msi_opts['PUPPET_AGENT_STARTUP_MODE']})
            on host, Command.new(reg_query_command, [], { :cmdexe => true })

            # (PA-620) environment.bat should be run before any cmd.exe shell command
            # in order to properly set up environment variables
            auto_run_key = "HKLM\\SOFTWARE\\Microsoft\\Command Processor\AutoRun"
            # TODO What's the best way to get the actual path to the script, respecting arch differences?
            environment_script = "C:\\Program Files\\Puppet Labs\\Puppet\bin\\environment.bat"
            reg_add_command = %Q(reg add "#{auto_run_key}" /v "PuppetEnvironment" /d "#{environment_script}")

            # emit the misc/versions.txt file which contains component versions for
            # puppet, facter, hiera, pxp-agent, packaging and vendored Ruby
            [
              "\\\"%ProgramFiles%\\Puppet Labs\\puppet\\misc\\versions.txt\\\"",
              "\\\"%ProgramFiles(x86)%\\Puppet Labs\\puppet\\misc\\versions.txt\\\""
            ].each do |path|
              on host, Command.new("\"if exist #{path} type #{path}\"", [], { :cmdexe => true })
            end
          end
        end

        # Installs a specified msi path on given hosts
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String] msi_path The path of the MSI - can be a local Windows style file path like
        #                   c:\temp\foo.msi OR a url like https://download.com/foo.msi or file://c:\temp\foo.msi
        # @param  [Hash{String=>String}] msi_opts MSI installer options
        # @option opts [Boolean] :debug output the MSI installation log when set to true
        #                 otherwise do not output log (false; default behavior)
        #
        # @example
        #  generic_install_msi_on(hosts, 'https://releases.hashicorp.com/vagrant/1.8.4/vagrant_1.8.4.msi', {}, {:debug => true})
        #
        # @api private
        def generic_install_msi_on(hosts, msi_path, msi_opts = {}, opts = {})
          block_on hosts do | host |
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

          end
        end

      end
    end
  end
end
