module Beaker
  module DSL
    module Helpers
      # Methods that help you interact and manage the state of your Beaker SUTs, these
      # methods do not require puppet to be installed to execute correctly
      module HostHelpers
        # @!macro [new] common_opts
        #   @param [Hash{Symbol=>String}] opts Options to alter execution.
        #   @option opts [Boolean] :silent (false) Do not produce log output
        #   @option opts [Array<Fixnum>] :acceptable_exit_codes ([0]) An array
        #     (or range) of integer exit codes that should be considered
        #     acceptable.  An error will be thrown if the exit code does not
        #     match one of the values in this list.
        #   @option opts [Boolean] :accept_all_exit_codes (false) Consider all
        #     exit codes as passing.
        #   @option opts [Boolean] :dry_run (false) Do not actually execute any
        #     commands on the SUT
        #   @option opts [String] :stdin (nil) Input to be provided during command
        #     execution on the SUT.
        #   @option opts [Boolean] :pty (false) Execute this command in a pseudoterminal.
        #   @option opts [Boolean] :expect_connection_failure (false) Expect this command
        #     to result in a connection failure, reconnect and continue execution.
        #   @option opts [Hash{String=>String}] :environment ({}) These will be
        #     treated as extra environment variables that should be set before
        #     running the command.
        #   @option opts [Boolean] :run_in_parallel Whether to run on each host in parallel.

        # The primary method for executing commands *on* some set of hosts.
        #
        # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String, Command]   command The command to execute on *host*.
        # @param [Proc]              block   Additional actions or assertions.
        # @!macro common_opts
        #
        # @example Most basic usage
        #     on hosts, 'ls /tmp'
        #
        # @example Allowing additional exit codes to pass
        #     on agents, 'puppet agent -t', :acceptable_exit_codes => [0,2]
        #
        # @example Using the returned result for any kind of checking
        #     if on(host, 'ls -la ~').stdout =~ /\.bin/
        #       ...do some action...
        #     end
        #
        # @example Using TestCase helpers from within a test.
        #     agents.each do |agent|
        #       on agent, 'cat /etc/puppet/puppet.conf' do
        #         assert_match stdout, /server = #{master}/, 'WTF Mate'
        #       end
        #     end
        #
        # @example Using a role (defined in a String)  to identify the host
        #   on "master", "echo hello"
        #
        # @example Using a role (defined in a Symbol) to identify the host
        #   on :dashboard, "echo hello"
        # @return [Result]   An object representing the outcome of *command*.
        # @raise  [FailTest] Raises an exception if *command* obviously fails.
        def on(host, command, opts = {}, &block)
          block_on host, opts do |host|
            if command.is_a? String
              cmd_opts = {}
              # add any additional environment variables to the command
              cmd_opts['ENV'] = opts[:environment] if opts[:environment]
              command_object = Command.new(command.to_s, [], cmd_opts)
            elsif command.is_a? Command
              if opts[:environment]
                command_object = command.clone
                command_object.environment = opts[:environment]
              else
                command_object = command
              end
            else
              msg = "DSL method `on` can only be called with a String or Beaker::Command"
              msg << " object as the command parameter, not #{command.class}."
              raise ArgumentError, msg
            end
            result = host.exec(command_object, opts)

            # Also, let additional checking be performed by the caller.
            if block
              case block.arity
                # block with arity of 0, just hand back yourself
              when 0
                yield self
                # block with arity of 1 or greater, hand back the result object
              else
                yield result
              end
            end
            result
          end
        end

        # The method for executing commands on the default host
        #
        # @param [String, Command]   command The command to execute on *host*.
        # @param [Proc]              block   Additional actions or assertions.
        # @!macro common_opts
        #
        # @example Most basic usage
        #     shell 'ls /tmp'
        #
        # @example Allowing additional exit codes to pass
        #     shell 'puppet agent -t', :acceptable_exit_codes => [0,2]
        #
        # @example Using the returned result for any kind of checking
        #     if shell('ls -la ~').stdout =~ /\.bin/
        #       ...do some action...
        #     end
        #
        # @example Using TestCase helpers from within a test.
        #     shell('cat /etc/puppet/puppet.conf') do |result|
        #       assert_match result.stdout, /server = #{master}/, 'WTF Mate'
        #     end
        #
        # @return [Result]   An object representing the outcome of *command*.
        # @raise  [FailTest] Raises an exception if *command* obviously fails.
        def shell(command, opts = {}, &block)
          on(default, command, opts, &block)
        end

        # Move a file from a remote to a local path
        # @note If using {Beaker::Host} for the hosts *scp* is not
        #   required on the system as it uses Ruby's net/scp library.  The
        #   net-scp gem however is required (and specified in the gemspec).
        #
        # @param [Host, #do_scp_from] host One or more hosts (or some object
        #                                  that responds like
        #                                  {Beaker::Host#do_scp_from}.
        # @param [String] from_path A remote path to a file.
        # @param [String] to_path   A local path to copy *from_path* to.
        # @!macro common_opts
        #
        # @return [Result] Returns the result of the SCP operation
        def scp_from host, from_path, to_path, opts = {}
          block_on host do |host|
            result = host.do_scp_from(from_path, to_path, opts)
            result.log logger
            result
          end
        end

        # Move a local file to a remote host using scp
        # @note If using {Beaker::Host} for the hosts *scp* is not
        #   required on the system as it uses Ruby's net/scp library.  The
        #   net-scp gem however is required (and specified in the gemspec.
        #   When using SCP with Windows it will now auto expand path when
        #   using `cygpath instead of failing or requiring full path
        #
        # @param [Host, #do_scp_to] host One or more hosts (or some object
        #                                that responds like
        #                                {Beaker::Host#do_scp_to}.
        # @param [String] from_path A local path to a file.
        # @param [String] to_path   A remote path to copy *from_path* to.
        # @!macro common_opts
        #
        # @return [Result] Returns the result of the SCP operation
        def scp_to host, from_path, to_path, opts = {}
          block_on host do |host|
            if host['platform'].include?('windows') && to_path.match('`cygpath')
              result = on host, "echo #{to_path}"
              to_path = result.raw_output.chomp
            end
            result = host.do_scp_to(from_path, to_path, opts)
            result.log logger
            result
          end
        end

        # Move a local file or directory to a remote host using rsync
        # @note rsync is required on the local host.
        #
        # @param [Host, #do_scp_to] host A host object that responds like
        #                                {Beaker::Host}.
        # @param [String] from_path A local path to a file or directory.
        # @param [String] to_path   A remote path to copy *from_path* to.
        # @!macro common_opts
        #
        # @return [Result] Returns the result of the rsync operation
        def rsync_to host, from_path, to_path, opts = {}
          block_on host do |host|
            if host['platform'].include?('windows') && to_path.match('`cygpath')
              result = host.echo "#{to_path}"
              to_path = result.raw_output.chomp
            end
            host.do_rsync_to(from_path, to_path, opts)
          end
        end

        # Copy a remote file to the local system and save it under a directory
        # meant for storing SUT files to be viewed in the event of test failures.
        #
        # Files are stored locally with the following structure:
        #   ./<archive_root>/<hostname>/<from_path>
        #
        # This can be used during the post-suite phase to persist relevant log
        # files from the SUTs so they can available with the test results
        # (without having to preserve the SUT host and SSH in after the fact).
        #
        # Example
        #
        #   Archive the Puppet Server log file from the master ('abc123'),
        #   and archive the Puppet Agent log file from the agent ('xyz098'):
        #
        #     archive_file_from(master, '/var/log/puppetlabs/puppetserver.log')
        #     archive_file_from(agent, '/var/log/puppetlabs/puppetagent.log')
        #
        #   Results in the following files on the test runner:
        #
        #     archive/sut-files/abc123/var/log/puppetlabs/puppetserver.log
        #     archive/sut-files/xyz098/var/log/puppetlabs/puppetagent.log
        #
        # @param [Host] host A host object (or some object that can be passed to
        #                    #scp_from)
        # @param [String] from_path A remote absolute path on the host to copy.
        # @!macro common_opts
        # @option [String] archive_root The local directory to store the copied
        #                               file under. Defaults to
        #                               'archive/sut-files'.
        # @option [String] archive_name The name of the archive to be copied to
        #                               archive_root. Defaults to
        #                               'sut-files.tgz'.
        #
        # @return [Result] Returns the result of the #scp_from operation.
        def archive_file_from(host, from_path, opts = {}, archive_root = 'archive/sut-files', archive_name = 'sut-files.tgz')
          require 'minitar'
          filedir = File.dirname(from_path)
          targetdir = File.join(archive_root, host.hostname, filedir)
          # full path to check for existance later
          filename = "#{targetdir}/" + File.basename(from_path)
          FileUtils.mkdir_p(targetdir)
          scp_from(host, from_path, targetdir, opts)
          # scp_from does succeed on a non-existant file, checking if the file/folder actually exists
          raise IOError, "No such file or directory - #{filename}" if not File.exist?(filename)

          create_tarball(archive_root, archive_name)
        end

        # @visibility private
        def create_tarball(path, archive_name)
          tgz = Zlib::GzipWriter.new(File.open(archive_name, 'wb'))
          Minitar.pack(path, tgz)
        end
        private :create_tarball

        # Create a remote file out of a string
        # @note This method uses Tempfile in Ruby's STDLIB as well as {#scp_to}.
        #
        # @param [Host, #do_scp_to] hosts One or more hosts (or some object
        #                                 that responds like
        #                                 {Beaker::Host#do_scp_from}.
        # @param [String] file_path A remote path to place *file_content* at.
        # @param [String] file_content The contents of the file to be placed.
        # @!macro common_opts
        # @option opts [String] :protocol Name of the underlying transfer method.
        #                                 Valid options are 'scp' or 'rsync'.
        #
        # @return [Result] Returns the result of the underlying SCP operation.
        def create_remote_file(hosts, file_path, file_content, opts = {})
          Tempfile.open 'beaker' do |tempfile|
            File.open(tempfile.path, 'w') { |file| file.puts file_content }

            opts[:protocol] ||= 'scp'
            case opts[:protocol]
            when 'scp'
              scp_to hosts, tempfile.path, file_path, opts
            when 'rsync'
              rsync_to hosts, tempfile.path, file_path, opts
            else
              logger.debug "Unsupported transfer protocol, returning nil"
              nil
            end
          end
        end

        # Execute a powershell script from file, remote file created from provided string
        # @note This method uses Tempfile in Ruby's STDLIB as well as {#create_remote_file}.
        #
        # @param [Host] hosts One or more hosts (or some object
        #                                 that responds like
        #                                 {Beaker::Host#do_scp_from}.
        # @param [String] powershell_script A string describing a set of powershell actions
        # @param [Hash{Symbol=>String}] opts Options to alter execution.
        # @option opts [Boolean] :run_in_parallel Whether to run on each host in parallel.
        #
        # @return [Result] Returns the result of the powershell command execution
        def execute_powershell_script_on(hosts, powershell_script, opts = {})
          block_on hosts, opts do |host|
            script_path = "beaker_powershell_script_#{Time.now.to_i}.ps1"
            create_remote_file(host, script_path, powershell_script, opts)
            native_path = script_path.tr('/', "\\")
            on host, powershell("", { "File" => native_path }), opts
          end
        end

        # Move a local script to a remote host and execute it
        # @note this relies on {#on} and {#scp_to}
        #
        # @param [Host, #do_scp_to] host One or more hosts (or some object
        #                                that responds like
        #                                {Beaker::Host#do_scp_from}.
        # @param [String] script A local path to find an executable script at.
        # @!macro common_opts
        # @param [Proc] block Additional tests to run after script has executed
        #
        # @return [Result] Returns the result of the underlying SCP operation.
        def run_script_on(host, script, opts = {}, &block)
          # this is unsafe as it uses the File::SEPARATOR will be set to that
          # of the coordinator node.  This works for us because we use cygwin
          # which will properly convert the paths.  Otherwise this would not
          # work for running tests on a windows machine when the coordinator
          # that the harness is running on is *nix. We should use
          # {Beaker::Host#temp_path} instead. TODO
          remote_path = File.join("", "tmp", File.basename(script))

          scp_to host, script, remote_path
          on host, remote_path, opts, &block
        end

        # Move a local script to default host and execute it
        # @see #run_script_on
        def run_script(script, opts = {}, &block)
          run_script_on(default, script, opts, &block)
        end

        # Install a package on a host
        #
        # @param [Host] host             A host object
        # @param [String] package_name   Name of the package to install
        #
        # @return [Result]   An object representing the outcome of *install command*.
        def install_package host, package_name, package_version = nil
          host.install_package package_name, '', package_version
        end

        # Uninstall a package on a host
        #
        # @param [Host] host             A host object
        # @param [String] package_name   Name of the package to uninstall
        #
        # @return [Result]   An object representing the outcome of *uninstall command*.
        def uninstall_package host, package_name
          host.uninstall_package package_name
        end

        # Check to see if a package is installed on a remote host
        #
        # @param [Host] host             A host object
        # @param [String] package_name   Name of the package to check for.
        #
        # @return [Boolean] true/false if the package is found
        def check_for_package host, package_name
          host.check_for_package package_name
        end

        # Upgrade a package on a host. The package must already be installed
        #
        # @param [Host] host             A host object
        # @param [String] package_name   Name of the package to install
        #
        # @return [Result]   An object representing the outcome of *upgrade command*.
        def upgrade_package host, package_name
          host.upgrade_package package_name
        end

        # Configure a host entry on the give host
        # @example: will add a host entry for forge.puppetlabs.com
        #   add_system32_hosts_entry(host, { :ip => '23.251.154.122', :name => 'forge.puppetlabs.com' })
        #
        # @return nil
        def add_system32_hosts_entry(host, opts = {})
          raise "nothing to do for #{host.name} on #{host['platform']}" unless host.is_powershell?

          hosts_file = 'C:\Windows\System32\Drivers\etc\hosts'
          host_entry = "#{opts['ip']}`t`t#{opts['name']}"
          on host, powershell("\$text = \\\"#{host_entry}\\\"; Add-Content -path '#{hosts_file}' -value \$text")
        end

        # Back up the given file in the current_dir to the new_dir
        #
        # @param host [Beaker::Host] The target host
        # @param current_dir [String] The directory containing the file to back up
        # @param new_dir [String] The directory to copy the file to
        # @param filename [String] The file to back up. Defaults to 'puppet.conf'
        #
        # @return [String, nil] The path to the file if the file exists, nil if it
        #   doesn't exist.
        def backup_the_file host, current_dir, new_dir, filename = 'puppet.conf'
          old_location = current_dir + '/' + filename
          new_location = new_dir + '/' + filename + '.bak'

          if host.file_exist? old_location
            host.exec(Command.new("cp #{old_location} #{new_location}"))
            return new_location
          else
            logger.warn "Could not backup file '#{old_location}': no such file"
            nil
          end
        end

        # Return a Hash with the Alternate Data Stream (ADS) name as well as the
        # base file path
        #
        # @param file_path [String] The full path with the ADS attached
        #
        # @return [Hash] The base file path and ADS name
        def win_ads_path(file_path)
          ads_path = {
            path: file_path,
            ads: nil,
          }

          split_path = file_path.split(':')

          if split_path.size > 2
            ads_path[:ads] = split_path.pop
            ads_path[:path] = split_path.join(':')
          end

          return ads_path
        end

        # Check whether a file exists on the host
        #
        # @param host [Beaker::Host] The target host
        # @param file_path [String] The absolute path of the file
        #
        # @return [Boolean] Whether the file exists on the host (using `test -f`)
        def file_exists_on(host, file_path)
          if host[:platform].include?('windows')
            command = %(Test-Path #{file_path})

            if file_path.include?(':')
              split_path = win_ads_path(file_path)

              command = %(Test-Path #{split_path[:path]})
              command += %( -AND Get-Item -path #{split_path[:path]} -stream #{split_path[:ads]}) if split_path[:ads]
            end

            command = powershell(command)
          else
            command = %(test -f "#{file_path}")
          end

          return on(host, command, { :accept_all_exit_codes => true }).exit_code.zero?
        end

        # Check whether a directory exists on the host
        #
        # @param host [Beaker::Host] The target host
        # @param dir_path [String] The absolute path of the directory
        #
        # @return [Boolean] Whether the directory exists on the host (using `test -d`)
        def directory_exists_on(host, dir_path)
          if host[:platform].include?('windows')
            dir_path = "#{dir_path}\\" unless (dir_path[-1].chr == '\\')

            command = Command.new(%{IF exist "#{dir_path}" ( exit 0 ) ELSE ( exit 1 )}, [], { :cmdexe => true })
          else
            command = Command.new(%(test -d "#{dir_path}"), [])
          end

          return on(host, command, { :accept_all_exit_codes => true }).exit_code.zero?
        end

        # Check whether a symlink exists on the host
        #
        # @param host [Beaker::Host] The target host
        # @param link_path [String] The absolute path of the symlink
        #
        # @return [Boolean] Whether the symlink exists on the host (using `test -L`)
        def link_exists_on(host, link_path)
          # Links are weird on windows, fall back to seeing if the file exists
          return file_exists_on(host, link_path) if host[:platform].include?('windows')

          return on(host, Command.new(%(test -L "#{link_path}"), accept_all_exit_codes: true)).exit_code.zero?
        end

        # Get the contents of a file on the host
        #
        # @param host [Beaker::Host] The target host
        # @param file_path [String] The absoltue path to the file
        #
        # @return [String] The contents of the file
        def file_contents_on(host, file_path)
          file_contents = nil

          split_path = win_ads_path(file_path)
          if file_exists_on(host, split_path[:path])
            if host[:platform].include?('windows')
              file_path.tr!('/', '\\')

              command = %{Get-Content -Raw -Path #{file_path}}
              command += %{ -Stream #{split_path[:ads]}} if split_path[:ads]

              file_contents = on(host, powershell(command))&.stdout&.strip
            else
              file_contents = on(host, %(cat "#{file_path}"))&.stdout&.strip
            end
          else
            logger.warn("File '#{file_path}' on '#{host} does not exist")
          end

          return file_contents
        end

        # Run a curl command on the provided host(s)
        #
        # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String, Command]   cmd The curl command to execute on *host*.
        # @param [Proc]              block   Additional actions or assertions.
        # @!macro common_opts
        #
        def curl_on(host, cmd, opts = {}, &block)
          on host, "curl --tlsv1 %s" % cmd, opts, &block
        end

        def curl_with_retries(_desc, host, url, desired_exit_codes, max_retries = 60, retry_interval = 1)
          opts = {
            :desired_exit_codes => desired_exit_codes,
            :max_retries => max_retries,
            :retry_interval => retry_interval,
          }
          retry_on(host, "curl -m 1 #{url}", opts)
        end

        # This command will execute repeatedly until success or it runs out with an error
        #
        # @param [Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String, Command]   command The command to execute on *host*.
        # @param [Hash{Symbol=>String}] opts Options to alter execution.
        # @param [Proc]              block   Additional actions or assertions.
        #
        # @option opts [Array<Fixnum>, Fixnum] :desired_exit_codes (0) An array
        #   or integer exit code(s) that should be considered
        #   acceptable.  An error will be thrown if the exit code never
        #   matches one of the values in this list.
        # @option opts [Fixnum] :max_retries (60) number of times the
        #   command will be tried before failing
        # @option opts [Float] :retry_interval (1) number of seconds
        #   that we'll wait between tries
        # @option opts [Boolean] :verbose (false)
        #
        # @return [Result] Result object of the last command execution
        def retry_on(host, command, opts = {}, &block)
          option_exit_codes     = opts[:desired_exit_codes]
          option_max_retries    = opts[:max_retries].to_i
          option_retry_interval = opts[:retry_interval].to_f
          desired_exit_codes    = option_exit_codes ? [option_exit_codes].flatten : [0]
          desired_exit_codes    = [0] if desired_exit_codes.empty?
          max_retries           = option_max_retries == 0 ? 60 : option_max_retries # nil & "" both return 0
          retry_interval        = option_retry_interval == 0 ? 1 : option_retry_interval
          verbose               = true.to_s == opts[:verbose]

          log_prefix = host.log_prefix
          logger.debug "\n#{log_prefix} #{Time.new.strftime('%H:%M:%S')}$ #{command}"
          logger.debug "  Trying command #{max_retries} times."
          logger.debug ".", add_newline: false

          result = on host, command, { :accept_all_exit_codes => true, :silent => !verbose }, &block
          num_retries = 0
          until desired_exit_codes.include?(result.exit_code)
            sleep retry_interval
            result = on host, command, { :accept_all_exit_codes => true, :silent => !verbose }, &block
            num_retries += 1
            logger.debug ".", add_newline: false
            if (num_retries > max_retries)
              logger.debug "  Command \`#{command}\` failed."
              fail("Command \`#{command}\` failed.")
            end
          end
          logger.debug "\n#{log_prefix} #{Time.new.strftime('%H:%M:%S')}$ #{command} ostensibly successful."
          result
        end

        # FIX: this should be moved into host/platform
        # @visibility private
        def run_cron_on(host, action, user, entry = "", &block)
          block_on host do |host|
            platform = host['platform']
            if platform.include?('solaris') || platform.include?('aix') then
              case action
              when :list   then args = '-l'
              when :remove then args = '-r'
              when :add
                on(host,
                   "echo '#{entry}' > /var/spool/cron/crontabs/#{user}",
                   &block)
              end

            else # default for GNU/Linux platforms
              case action
              when :list   then args = '-l -u'
              when :remove then args = '-r -u'
              when :add
                on(host,
                   "echo '#{entry}' > /tmp/#{user}.cron && " +
                   "crontab -u #{user} /tmp/#{user}.cron",
                   &block)
              end
            end

            if args
              case action
              when :list, :remove then on(host, "crontab #{args} #{user}", &block)
              end
            end
          end
        end

        # 'echo' the provided value on the given host(s)
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [String] val The string to 'echo' on the host(s)
        # @return [String, Array<String> The echo'ed value(s) returned by the host(s)
        def echo_on hosts, val
          block_on hosts do |host|
            if host.is_powershell?
              host.exec(Command.new("echo #{val}")).stdout.chomp
            else
              host.exec(Command.new("echo \"#{val}\"")).stdout.chomp
            end
          end
        end
      end
    end
  end
end
