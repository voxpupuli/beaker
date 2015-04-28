module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains methods to help installing/upgrading PE builds - including Higgs installs
      #
      # To mix this is into a class you need the following:
      # * a method *hosts* that yields any hosts implementing
      #   {Beaker::Host}'s interface to act upon.
      # * a method *options* that provides an options hash, see {Beaker::Options::OptionsHash}
      # * the module {Beaker::DSL::Roles} that provides access to the various hosts implementing
      #   {Beaker::Host}'s interface to act upon
      # * the module {Beaker::DSL::Wrappers} the provides convenience methods for {Beaker::DSL::Command} creation
      module PEUtils

        #Sort array of hosts so that it has the correct order for PE installation based upon each host's role
        # @example
        #  h = sorted_hosts
        #
        # @note Order for installation should be
        #        First : master
        #        Second: database host (if not same as master)
        #        Third:  dashboard (if not same as master or database)
        #        Fourth: everything else
        #
        # @!visibility private
        def sorted_hosts
          special_nodes = []
          [master, database, dashboard].uniq.each do |host|
            special_nodes << host if host != nil
          end
          real_agents = agents - special_nodes
          special_nodes + real_agents
        end

        #Create the PE install command string based upon the host and options settings
        # @param [Host] host The host that PE is to be installed on
        #                    For UNIX machines using the full PE installer, the host object must have the 'pe_installer' field set correctly.
        # @param [Hash{Symbol=>String}] opts The options
        # @option opts [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
        #                          (Othersie uses individual Windows hosts pe_ver)
        # @option opts [String]  :pe_ver Default PE version to install or upgrade to
        #                          (Otherwise uses individual hosts pe_ver)
        # @option opts [Boolean] :pe_debug (false) Should we run the installer in debug mode?
        # @example
        #      on host, "#{installer_cmd(host, opts)} -a #{host['working_dir']}/answers"
        # @api private
        def installer_cmd(host, opts)
          version = host['pe_ver'] || opts[:pe_ver]
          if host['platform'] =~ /windows/
            log_file = "#{File.basename(host['working_dir'])}.log"
            pe_debug = host[:pe_debug] || opts[:pe_debug] ? " && cat #{log_file}" : ''
            if host.is_cygwin?
              "cd #{host['working_dir']} && cmd /C 'start /w msiexec.exe /qn /L*V #{log_file} /i #{host['dist']}.msi PUPPET_MASTER_SERVER=#{master} PUPPET_AGENT_CERTNAME=#{host}'#{pe_debug}"
            else
              "cd #{host['working_dir']} &&  msiexec.exe /qn /L*V #{log_file} /i #{host['dist']}.msi PUPPET_MASTER_SERVER=#{master} PUPPET_AGENT_CERTNAME=#{host}#{pe_debug}"
            end
          # Frictionless install didn't exist pre-3.2.0, so in that case we fall
          # through and do a regular install.
          elsif host['roles'].include? 'frictionless' and ! version_is_less(version, '3.2.0')
            # PE 3.4 introduced the ability to pass in config options to the bash script in the form
            # of <section>:<key>=<value>
            frictionless_install_opts = []
            if host.has_key?('frictionless_options') and !  version_is_less(version, '3.4.0')
              # since we have options to pass in, we need to tell the bash script
              host['frictionless_options'].each do |section, settings|
                settings.each do |key, value|
                  frictionless_install_opts << "#{section}:#{key}=#{value}"
                end
              end
            end

            pe_debug = host[:pe_debug] || opts[:pe_debug] ? ' -x' : ''
            "cd #{host['working_dir']} && curl --tlsv1 -kO https://#{master}:8140/packages/#{version}/install.bash && bash#{pe_debug} install.bash #{frictionless_install_opts.join(' ')}".strip
          elsif host['platform'] =~ /osx/
            version = host['pe_ver'] || opts[:pe_ver]
            pe_debug = host[:pe_debug] || opts[:pe_debug] ? ' -verboseR' : ''
            "cd #{host['working_dir']} && hdiutil attach #{host['dist']}.dmg && installer#{pe_debug} -pkg /Volumes/puppet-enterprise-#{version}/puppet-enterprise-installer-#{version}.pkg -target /"
          elsif host['platform'] =~ /eos/
            commands = ['enable', "extension puppet-enterprise-#{version}-#{host['platform']}.swix"]
            command = commands.join("\n")
            "Cli -c '#{command}'"
          else
            pe_debug = host[:pe_debug] || opts[:pe_debug]  ? ' -D' : ''
            "cd #{host['working_dir']}/#{host['dist']} && ./#{host['pe_installer']}#{pe_debug} -a #{host['working_dir']}/answers"
          end
        end

        #Determine the PE package to download/upload on a mac host, download/upload that package onto the host.
        # Assumed file name format: puppet-enterprise-3.3.0-rc1-559-g97f0833-osx-10.9-x86_64.dmg.
        # @param [Host] host The mac host to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe_on_mac(host, opts)
          path = host['pe_dir'] || opts[:pe_dir]
          local = File.directory?(path)
          filename = "#{host['dist']}"
          extension = ".dmg"
          if local
            if not File.exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            scp_to host, "#{path}/#{filename}#{extension}", "#{host['working_dir']}/#{filename}#{extension}"
          else
            if not link_exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            if opts[:fetch_local_then_push_to_host]
              fetch_and_push_pe(host, path, filename, extension)
            else
              on host, "cd #{host['working_dir']}; curl -O #{path}/#{filename}#{extension}"
            end
          end
        end

        #Determine the PE package to download/upload on a windows host, download/upload that package onto the host.
        #Assumed file name format: puppet-enterprise-3.3.0-rc1-559-g97f0833.msi
        # @param [Host] host The windows host to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver_win Default PE version to install or upgrade to
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe_on_windows(host, opts)
          path = host['pe_dir'] || opts[:pe_dir]
          local = File.directory?(path)
          version = host['pe_ver'] || opts[:pe_ver_win]
          filename = "#{host['dist']}"
          extension = ".msi"
          if local
            if not File.exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            scp_to host, "#{path}/#{filename}#{extension}", "#{host['working_dir']}/#{filename}#{extension}"
          else
            if not link_exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            if opts[:fetch_local_then_push_to_host]
              fetch_and_push_pe(host, path, filename, extension)
              on host, "cd #{host['working_dir']}; chmod 644 #{filename}#{extension}"
            elsif host.is_cygwin?
              on host, "cd #{host['working_dir']}; curl -O #{path}/#{filename}#{extension}"
            else
              on host, powershell("$webclient = New-Object System.Net.WebClient;  $webclient.DownloadFile('#{path}/#{filename}#{extension}','#{host['working_dir']}\\#{filename}#{extension}')")
            end
          end
        end

        #Determine the PE package to download/upload on a unix style host, download/upload that package onto the host
        #and unpack it.
        # @param [Host] host The unix style host to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe_on_unix(host, opts)
          path = host['pe_dir'] || opts[:pe_dir]
          local = File.directory?(path)
          filename = "#{host['dist']}"
          if local
            extension = File.exists?("#{path}/#{filename}.tar.gz") ? ".tar.gz" : ".tar"
            if not File.exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            scp_to host, "#{path}/#{filename}#{extension}", "#{host['working_dir']}/#{filename}#{extension}"
            if extension =~ /gz/
              on host, "cd #{host['working_dir']}; gunzip #{filename}#{extension}"
            end
            if extension =~ /tar/
              on host, "cd #{host['working_dir']}; tar -xvf #{filename}.tar"
            end
          else
            if host['platform'] =~ /eos/
              extension = '.swix'
            else
              extension = link_exists?("#{path}/#{filename}.tar.gz") ? ".tar.gz" : ".tar"
            end
            if not link_exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end

            if host['platform'] =~ /eos/
              commands = ['enable', "copy #{path}/#{filename}#{extension} extension:"]
              command = commands.join("\n")
              on host, "Cli -c '#{command}'"
            else
              unpack = 'tar -xvf -'
              unpack = extension =~ /gz/ ? 'gunzip | ' + unpack  : unpack
              if opts[:fetch_local_then_push_to_host]
                fetch_and_push_pe(host, path, filename, extension)
                command_file_push = 'cat '
              else
                command_file_push = "curl #{path}/"
              end
              on host, "cd #{host['working_dir']}; #{command_file_push}#{filename}#{extension} | #{unpack}"

            end
          end
        end

        #Determine the PE package to download/upload per-host, download/upload that package onto the host
        #and unpack it.
        # @param [Array<Host>] hosts The hosts to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver Default PE version to install or upgrade to
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
        #                  (Otherwise uses individual Windows hosts pe_ver)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe(hosts, opts)
          hosts.each do |host|
            # We install Puppet from the master for frictionless installs, so we don't need to *fetch* anything
            next if host['roles'].include?('frictionless') && (! version_is_less(opts[:pe_ver] || host['pe_ver'], '3.2.0'))

            if host['platform'] =~ /windows/
              fetch_pe_on_windows(host, opts)
            elsif host['platform'] =~ /osx/
              fetch_pe_on_mac(host, opts)
            else
              fetch_pe_on_unix(host, opts)
            end
          end
        end

        #Classify the master so that it can deploy frictionless packages for a given host.
        # @param [Host] host The host to install pacakges for
        # @api private
        def deploy_frictionless_to_master(host)
          klass = host['platform'].gsub(/-/, '_').gsub(/\./,'')
          klass = "pe_repo::platform::#{klass}"
          on dashboard, "cd /opt/puppet/share/puppet-dashboard && /opt/puppet/bin/bundle exec /opt/puppet/bin/rake nodeclass:add[#{klass},skip]"
          on dashboard, "cd /opt/puppet/share/puppet-dashboard && /opt/puppet/bin/bundle exec /opt/puppet/bin/rake node:add[#{master},,,skip]"
          on dashboard, "cd /opt/puppet/share/puppet-dashboard && /opt/puppet/bin/bundle exec /opt/puppet/bin/rake node:addclass[#{master},#{klass}]"
          on master, puppet("agent -t"), :acceptable_exit_codes => [0,2]
        end

        #Perform a Puppet Enterprise upgrade or install
        # @param [Array<Host>] hosts The hosts to install or upgrade PE on
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver Default PE version to install or upgrade to
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
        #                  (Otherwise uses individual Windows hosts pe_ver)
        # @option opts [Symbol] :type (:install) One of :upgrade or :install
        # @option opts [Boolean] :set_console_password Should we set the PE console password in the answers file?  Used during upgrade only.
        # @option opts [Hash<String>] :answers Pre-set answers based upon ENV vars and defaults
        #                             (See {Beaker::Options::Presets.env_vars})
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        #
        # @example
        #  do_install(hosts, {:type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win =>  version_win})
        #
        # @api private
        #
        def do_install hosts, opts = {}
          masterless = (defined? options) ? options[:masterless] : false
          opts[:masterless] = masterless # has to pass masterless down for answer generation awareness
          opts[:type] = opts[:type] || :install
          unless masterless
            pre30database = version_is_less(opts[:pe_ver] || database['pe_ver'], '3.0')
            pre30master = version_is_less(opts[:pe_ver] || master['pe_ver'], '3.0')

            unless version_is_less(opts[:pe_ver] || master['pe_ver'], '3.4')
              master['puppetservice'] = 'pe-puppetserver'
            end
          end

          # Set PE distribution for all the hosts, create working dir
          use_all_tar = ENV['PE_USE_ALL_TAR'] == 'true'
          hosts.each do |host|
            host['pe_installer'] ||= 'puppet-enterprise-installer'
            if host['platform'] !~ /windows|osx/
              platform = use_all_tar ? 'all' : host['platform']
              version = host['pe_ver'] || opts[:pe_ver]
              host['dist'] = "puppet-enterprise-#{version}-#{platform}"
            elsif host['platform'] =~ /osx/
              version = host['pe_ver'] || opts[:pe_ver]
              host['dist'] = "puppet-enterprise-#{version}-#{host['platform']}"
            elsif host['platform'] =~ /windows/
              version = host[:pe_ver] || opts['pe_ver_win']
              should_install_64bit = !(version_is_less(version, '3.4')) && host.is_x86_64? && !host['install_32'] && !opts['install_32']
              #only install 64bit builds if
              # - we are on pe version 3.4+
              # - we do not have install_32 set on host
              # - we do not have install_32 set globally
              if !(version_is_less(version, '4.0'))
                if should_install_64bit
                  host['dist'] = "puppet-agent-#{version}-x64"
                else
                  host['dist'] = "puppet-agent-#{version}-x86"
                end
              elsif should_install_64bit
                host['dist'] = "puppet-enterprise-#{version}-x64"
              else
                host['dist'] = "puppet-enterprise-#{version}"
              end
            end
            host['working_dir'] = host.tmpdir(Time.new.strftime("%Y-%m-%d_%H.%M.%S"))
          end

          fetch_pe(hosts, opts)

          install_hosts = hosts.dup
          unless masterless
            # If we're installing a database version less than 3.0, ignore the database host
            install_hosts.delete(database) if pre30database and database != master and database != dashboard
          end

          install_hosts.each do |host|
            if host['platform'] =~ /windows/
              on host, installer_cmd(host, opts)
              if not host.is_cygwin?
                # HACK: for some reason, post install we need to refresh the connection to make puppet available for execution
                host.close
              end
            else
              # We only need answers if we're using the classic installer
              version = host['pe_ver'] || opts[:pe_ver]
              if host['roles'].include?('frictionless') &&  (! version_is_less(version, '3.2.0'))
                # If We're *not* running the classic installer, we want
                # to make sure the master has packages for us.
                deploy_frictionless_to_master(host)
                on host, installer_cmd(host, opts)
              elsif host['platform'] =~ /osx|eos/
                # If we're not frictionless, we need to run the OSX special-case
                on host, installer_cmd(host, opts)
                #set the certname and master
                on host, puppet("config set server #{master}")
                on host, puppet("config set certname #{host}")
                #run once to request cert
                acceptable_codes = host['platform'] =~ /osx/ ? [1] : [0, 1]
                on host, puppet_agent('-t'), :acceptable_exit_codes => acceptable_codes
              else
                answers = Beaker::Answers.create(opts[:pe_ver] || host['pe_ver'], hosts, opts)
                create_remote_file host, "#{host['working_dir']}/answers", answers.answer_string(host)
                on host, installer_cmd(host, opts)
              end
            end

            # On each agent, we ensure the certificate is signed then shut down the agent
            sign_certificate_for(host) unless masterless
            stop_agent_on(host)
          end

          unless masterless
            # Wait for PuppetDB to be totally up and running (post 3.0 version of pe only)
            sleep_until_puppetdb_started(database) unless pre30database

            # Run the agent once to ensure everything is in the dashboard
            install_hosts.each do |host|
              on host, puppet_agent('-t'), :acceptable_exit_codes => [0,2]

              # Workaround for PE-1105 when deploying 3.0.0
              # The installer did not respect our database host answers in 3.0.0,
              # and would cause puppetdb to be bounced by the agent run. By sleeping
              # again here, we ensure that if that bounce happens during an upgrade
              # test we won't fail early in the install process.
              if host['pe_ver'] == '3.0.0' and host == database
                sleep_until_puppetdb_started(database)
              end
            end

            install_hosts.each do |host|
              wait_for_host_in_dashboard(host)
            end

            if pre30master
              task = 'nodegroup:add_all_nodes group=default'
            else
              task = 'defaultgroup:ensure_default_group'
            end
            on dashboard, "/opt/puppet/bin/rake -sf /opt/puppet/share/puppet-dashboard/Rakefile #{task} RAILS_ENV=production"

            # Now that all hosts are in the dashbaord, run puppet one more
            # time to configure mcollective
            on install_hosts, puppet_agent('-t'), :acceptable_exit_codes => [0,2]
          end
        end

        #Install PE based upon host configuration and options
        # @example
        #  install_pe
        #
        # @note Either pe_ver and pe_dir should be set in the ENV or each host should have pe_ver and pe_dir set individually.
        #       Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz)
        #       for Unix like systems and puppet-enterprise-VERSION.msi for Windows systems.
        #
        def install_pe
          #process the version files if necessary
          hosts.each do |host|
            host['pe_dir'] ||= options[:pe_dir]
            if host['platform'] =~ /windows/
              host['pe_ver'] = host['pe_ver'] || options['pe_ver'] ||
                Beaker::Options::PEVersionScraper.load_pe_version(host[:pe_dir] || options[:pe_dir], options[:pe_version_file_win])
            else
              host['pe_ver'] = host['pe_ver'] || options['pe_ver'] ||
                Beaker::Options::PEVersionScraper.load_pe_version(host[:pe_dir] || options[:pe_dir], options[:pe_version_file])
            end
          end
          #send in the global options hash
          do_install sorted_hosts, options
        end

        #Upgrade PE based upon host configuration and options
        # @param [String] path A path (either local directory or a URL to a listing of PE builds).
        #                      Will contain a LATEST file indicating the latest build to install.
        #                      This is ignored if a pe_upgrade_ver and pe_upgrade_dir are specified
        #                      in the host configuration file.
        # @example
        #  upgrade_pe("http://neptune.puppetlabs.lan/3.0/ci-ready/")
        #
        # @note Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz)
        #       for Unix like systems and puppet-enterprise-VERSION.msi for Windows systems.
        def upgrade_pe path=nil
          set_console_password = false
          # if we are upgrading from something lower than 3.4 then we need to set the pe console password
          if (dashboard[:pe_ver] ? version_is_less(dashboard[:pe_ver], "3.4.0") : true)
            set_console_password = true
          end
          # get new version information
          hosts.each do |host|
            host['pe_dir'] = host['pe_upgrade_dir'] || path
            if host['platform'] =~ /windows/
              host['pe_ver'] = host['pe_upgrade_ver'] || options['pe_upgrade_ver'] ||
                Options::PEVersionScraper.load_pe_version(host['pe_dir'], options[:pe_version_file_win])
            else
              host['pe_ver'] = host['pe_upgrade_ver'] || options['pe_upgrade_ver'] ||
                Options::PEVersionScraper.load_pe_version(host['pe_dir'], options[:pe_version_file])
            end
            if version_is_less(host['pe_ver'], '3.0')
              host['pe_installer'] ||= 'puppet-enterprise-upgrader'
            end
          end
          # send in the global options hash
          do_install(sorted_hosts, options.merge({:type => :upgrade, :set_console_password => set_console_password}))
          options['upgrade'] = true
        end

        #Create the Higgs install command string based upon the host and options settings.  Installation command will be run as a
        #background process.  The output of the command will be stored in the provided host['higgs_file'].
        # @param [Host] host The host that Higgs is to be installed on
        #                    The host object must have the 'working_dir', 'dist' and 'pe_installer' field set correctly.
        # @api private
        def higgs_installer_cmd host

          "cd #{host['working_dir']}/#{host['dist']} ; nohup ./#{host['pe_installer']} <<<Y > #{host['higgs_file']} 2>&1 &"

        end

        #Perform a Puppet Enterprise Higgs install up until web browser interaction is required, runs on linux hosts only.
        # @param [Host] host The host to install higgs on
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver Default PE version to install
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @raise [StandardError] When installation times out
        #
        # @example
        #  do_higgs_install(master, {:pe_dir => path, :pe_ver => version})
        #
        # @api private
        #
        def do_higgs_install host, opts
          use_all_tar = ENV['PE_USE_ALL_TAR'] == 'true'
          platform = use_all_tar ? 'all' : host['platform']
          version = host['pe_ver'] || opts[:pe_ver]
          host['dist'] = "puppet-enterprise-#{version}-#{platform}"

          use_all_tar = ENV['PE_USE_ALL_TAR'] == 'true'
          host['pe_installer'] ||= 'puppet-enterprise-installer'
          host['working_dir'] = host.tmpdir(Time.new.strftime("%Y-%m-%d_%H.%M.%S"))

          fetch_pe([host], opts)

          host['higgs_file'] = "higgs_#{File.basename(host['working_dir'])}.log"
          on host, higgs_installer_cmd(host), opts

          #wait for output to host['higgs_file']
          #we're all done when we find this line in the PE installation log
          higgs_re = /Please\s+go\s+to\s+https:\/\/.*\s+in\s+your\s+browser\s+to\s+continue\s+installation/m
          res = Result.new(host, 'tmp cmd')
          tries = 10
          attempts = 0
          prev_sleep = 0
          cur_sleep = 1
          while (res.stdout !~ higgs_re) and (attempts < tries)
            res = on host, "cd #{host['working_dir']}/#{host['dist']} && cat #{host['higgs_file']}", :accept_all_exit_codes => true
            attempts += 1
            sleep( cur_sleep )
            prev_sleep = cur_sleep
            cur_sleep = cur_sleep + prev_sleep
          end

          if attempts >= tries
            raise "Failed to kick off PE (Higgs) web installation"
          end
        end

        #Install Higgs up till the point where you need to continue installation in a web browser, defaults to execution
        #on the master node.
        #@param [Host] higgs_host The host to install Higgs on (supported on linux platform only)
        # @example
        #  install_higgs
        #
        # @note Either pe_ver and pe_dir should be set in the ENV or each host should have pe_ver and pe_dir set individually.
        #       Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz).
        #
        def install_higgs( higgs_host = master )
          #process the version files if necessary
          master['pe_dir'] ||= options[:pe_dir]
          master['pe_ver'] = master['pe_ver'] || options['pe_ver'] ||
            Beaker::Options::PEVersionScraper.load_pe_version(master[:pe_dir] || options[:pe_dir], options[:pe_version_file])
          if higgs_host['platform'] =~ /osx|windows/
            raise "Attempting higgs installation on host #{higgs_host.name} with unsupported platform #{higgs_host['platform']}"
          end
          #send in the global options hash
          do_higgs_install higgs_host, options
        end

        # Grabs the pe file from a remote host to the machine running Beaker, then
        # scp's the file out to the host.
        #
        # @param [Host] host The host to install on
        # @param [String] path path to the install file
        # @param [String] filename the filename of the pe file (without the extension)
        # @param [String] extension the extension of the pe file
        # @param [String] local_dir the directory to store the pe file in on
        #                   the Beaker-running-machine
        #
        # @api private
        # @return nil
        def fetch_and_push_pe(host, path, filename, extension, local_dir='tmp/pe')
          fetch_http_file("#{path}", "#{filename}#{extension}", local_dir)
          scp_to host, "#{local_dir}/#{filename}#{extension}", host['working_dir']
        end

      end
    end
  end
end
