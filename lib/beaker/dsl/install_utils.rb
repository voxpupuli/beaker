require 'pathname'

module Beaker
  module DSL
    #
    # This module contains methods to help cloning, extracting git info,
    # ordering of Puppet packages, and installing ruby projects that
    # contain an `install.rb` script.
    #
    # To mix this is into a class you need the following:
    # * a method *hosts* that yields any hosts implementing
    #   {Beaker::Host}'s interface to act upon.
    # * a method *options* that provides an options hash, see {Beaker::Options::OptionsHash}
    # * the module {Beaker::DSL::Roles} that provides access to the various hosts implementing
    #   {Beaker::Host}'s interface to act upon
    # * the module {Beaker::DSL::Wrappers} the provides convenience methods for {Beaker::DSL::Command} creation
    module InstallUtils

      # The default install path
      SourcePath  = "/opt/puppet-git-repos"

      # A regex to know if the uri passed is pointing to a git repo
      GitURI       = %r{^(git|https?|file)://|^git@|^gitmirror@}

      # Github's ssh signature for cloning via ssh
      GitHubSig   = 'github.com,207.97.227.239 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=='

      # @param [String] uri A uri in the format of <git uri>#<revision>
      #                     the `git://`, `http://`, `https://`, and ssh
      #                     (if cloning as the remote git user) protocols
      #                     are valid for <git uri>
      #
      # @example Usage
      #     project = extract_repo_info_from 'git@github.com:puppetlabs/SuperSecretSauce#what_is_justin_doing'
      #
      #     puts project[:name]
      #     #=> 'SuperSecretSauce'
      #
      #     puts project[:rev]
      #     #=> 'what_is_justin_doing'
      #
      # @return [Hash{Symbol=>String}] Returns a hash containing the project
      #                                name, repository path, and revision
      #                                (defaults to HEAD)
      #
      # @api dsl
      def extract_repo_info_from uri
        project = {}
        repo, rev = uri.split('#', 2)
        project[:name] = Pathname.new(repo).basename('.git').to_s
        project[:path] = repo
        project[:rev]  = rev || 'HEAD'
        return project
      end

      # Takes an array of package info hashes (like that returned from
      # {#extract_repo_info_from}) and sorts the `puppet`, `facter`, `hiera`
      # packages so that puppet's dependencies will be installed first.
      #
      # @!visibility private
      def order_packages packages_array
        puppet = packages_array.select {|e| e[:name] == 'puppet' }
        puppet_depends_on = packages_array.select do |e|
          e[:name] == 'hiera' or e[:name] == 'facter'
        end
        depends_on_puppet = (packages_array - puppet) - puppet_depends_on
        [puppet_depends_on, puppet, depends_on_puppet].flatten
      end

      # @param [Host] host An object implementing {Beaker::Hosts}'s
      #                    interface.
      # @param [String] path The path on the remote [host] to the repository
      # @param [Hash{Symbol=>String}] repository A hash representing repo
      #                                          info like that emitted by
      #                                          {#extract_repo_info_from}
      #
      # @example Getting multiple project versions
      #     versions = [puppet_repo, facter_repo, hiera_repo].inject({}) do |vers, repo_info|
      #       vers.merge(find_git_repo_versions(host, '/opt/git-puppet-repos', repo_info) )
      #     end
      # @return [Hash] Executes git describe on [host] and returns a Hash
      #                with the key of [repository[:name]] and value of
      #                the output from git describe.
      #
      # @note This requires the helper methods:
      #       * {Beaker::DSL::Structure#step}
      #       * {Beaker::DSL::Helpers#on}
      #
      # @api dsl
      def find_git_repo_versions host, path, repository
        version = {}
        step "Grab version for #{repository[:name]}" do
          on host, "cd #{path}/#{repository[:name]} && " +
                    "git describe || true" do
            version[repository[:name]] = stdout.chomp
          end
        end
        version
      end

      #
      # @see #find_git_repo_versions
      def install_from_git host, path, repository
        name   = repository[:name]
        repo   = repository[:path]
        rev    = repository[:rev]
        target = "#{path}/#{name}"

        step "Clone #{repo} if needed" do
          on host, "test -d #{path} || mkdir -p #{path}"
          on host, "test -d #{target} || git clone #{repo} #{target}"
        end

        step "Update #{name} and check out revision #{rev}" do
          commands = ["cd #{target}",
                      "remote rm origin",
                      "remote add origin #{repo}",
                      "fetch origin",
                      "clean -fdx",
                      "checkout -f #{rev}"]
          on host, commands.join(" && git ")
        end

        step "Install #{name} on the system" do
          # The solaris ruby IPS package has bindir set to /usr/ruby/1.8/bin.
          # However, this is not the path to which we want to deliver our
          # binaries. So if we are using solaris, we have to pass the bin and
          # sbin directories to the install.rb
          install_opts = ''
          install_opts = '--bindir=/usr/bin --sbindir=/usr/sbin' if
            host['platform'].include? 'solaris'

            on host,  "cd #{target} && " +
                      "if [ -f install.rb ]; then " +
                      "ruby ./install.rb #{install_opts}; " +
                      "else true; fi"
        end
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
          version = host[:pe_ver] || opts['pe_ver_win']
          log_file = "#{File.basename(host['working_dir'])}.log"
          pe_debug = host[:pe_debug] || opts[:pe_debug] ? " && cat #{log_file}" : ''
          "cd #{host['working_dir']} && cmd /C 'start /w msiexec.exe /qn /L*V #{log_file} /i puppet-enterprise-#{version}.msi PUPPET_MASTER_SERVER=#{master} PUPPET_AGENT_CERTNAME=#{host}'#{pe_debug}"
        elsif host['platform'] =~ /osx/
          version = host['pe_ver'] || opts[:pe_ver]
          pe_debug = host[:pe_debug] || opts[:pe_debug] ? ' -verboseR' : ''
          "cd #{host['working_dir']} && hdiutil attach #{host['dist']}.dmg && installer#{pe_debug} -pkg /Volumes/puppet-enterprise-#{version}/puppet-enterprise-installer-#{version}.pkg -target /"

        # Frictionless install didn't exist pre-3.2.0, so in that case we fall
        # through and do a regular install.
        elsif host['roles'].include? 'frictionless' and ! version_is_less(version, '3.2.0')
          pe_debug = host[:pe_debug] || opts[:pe_debug] ? ' -x' : ''
          "cd #{host['working_dir']} && curl -kO https://#{master}:8140/packages/#{version}/install.bash && bash#{pe_debug} install.bash"
        else
          pe_debug = host[:pe_debug] || opts[:pe_debug]  ? ' -D' : ''
          "cd #{host['working_dir']}/#{host['dist']} && ./#{host['pe_installer']}#{pe_debug} -a #{host['working_dir']}/answers"
        end
      end

      #Create the Higgs install command string based upon the host and options settings.  Installation command will be run as a 
      #background process.  The output of the command will be stored in the provided host['higgs_file'].
      # @param [Host] host The host that Higgs is to be installed on
      #                    The host object must have the 'working_dir', 'dist' and 'pe_installer' field set correctly.
      # @api private
      def higgs_installer_cmd host

        "cd #{host['working_dir']}/#{host['dist']} ; nohup ./#{host['pe_installer']} <<<Y > #{host['higgs_file']} 2>&1 &"

      end

      #Determine is a given URL is accessible
      #@param [String] link The URL to examine
      #@return [Boolean] true if the URL has a '200' HTTP response code, false otherwise
      #@example
      #  extension = link_exists?("#{URL}.tar.gz") ? ".tar.gz" : ".tar"
      # @api private
      def link_exists?(link)
        require "net/http"
        require "net/https"
        require "open-uri"
        url = URI.parse(link)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == 'https')
        http.start do |http|
          return http.head(url.request_uri).code == "200"
        end
      end

      # Fetch file_name from the given base_url into dst_dir.
      #
      # @param [String] base_url The base url from which to recursively download
      #                          files.
      # @param [String] file_name The trailing name compnent of both the source url
      #                           and the destination file.
      # @param [String] dst_dir The local destination directory.
      #
      # @return [String] dst The name of the newly-created file.
      #
      # @!visibility private
      def fetch_http_file(base_url, file_name, dst_dir)
        FileUtils.makedirs(dst_dir)
        src = "#{base_url}/#{file_name}"
        dst = File.join(dst_dir, file_name)
        if File.exists?(dst)
          logger.notify "Already fetched #{dst}"
        else
          logger.notify "Fetching: #{src}"
          logger.notify "  and saving to #{dst}"
          open(src) do |remote|
            File.open(dst, "w") do |file|
              FileUtils.copy_stream(remote, file)
            end
          end
        end
        return dst
      end

      # Recursively fetch the contents of the given http url, ignoring
      # `index.html` and `*.gif` files.
      #
      # @param [String] url The base http url from which to recursively download
      #                     files.
      # @param [String] dst_dir The local destination directory.
      #
      # @return [String] dst The name of the newly-created subdirectory of
      #                      dst_dir.
      #
      # @!visibility private
      def fetch_http_dir(url, dst_dir)
        logger.notify "fetch_http_dir (url: #{url}, dst_dir #{dst_dir})"
        if url[-1, 1] !~ /\//
          url += '/'
        end
        url = URI.parse(url)
        chunks = url.path.split('/')
        dst = File.join(dst_dir, chunks.last)
        #determine directory structure to cut
        #only want to keep the last directory, thus cut total number of dirs - 2 (hostname + last dir name)
        cut = chunks.length - 2
        wget_command = "wget -nv -P #{dst_dir} --reject \"index.html*\",\"*.gif\" --cut-dirs=#{cut} -np -nH --no-check-certificate -r #{url}"

        logger.notify "Fetching remote directory: #{url}"
        logger.notify "  and saving to #{dst}"
        logger.notify "  using command: #{wget_command}"

        #in ruby 1.9+ we can upgrade this to popen3 to gain access to the subprocess pid
        result = `#{wget_command} 2>&1`
        result.each_line do |line|
          logger.debug(line)
        end
        if $?.to_i != 0
          raise "Failed to fetch_remote_dir '#{url}' (exit code #{$?}"
        end
        dst
      end

      #Determine the PE package to download/upload on a mac host, download/upload that package onto the host.
      # Assumed file name format: puppet-enterprise-3.3.0-rc1-559-g97f0833-osx-10.9-x86_64.dmg.
      # @param [Host] host The mac host to download/upload and unpack PE onto
      # @param  [Hash{Symbol=>Symbol, String}] opts The options
      # @option opts [String] :pe_dir Default directory or URL to pull PE package from
      #                  (Otherwise uses individual hosts pe_dir)
      # @api private
      def fetch_puppet_on_mac(host, opts)
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
          on host, "cd #{host['working_dir']}; curl -O #{path}/#{filename}#{extension}"
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
      # @api private
      def fetch_puppet_on_windows(host, opts)
        path = host['pe_dir'] || opts[:pe_dir]
        local = File.directory?(path)
        version = host['pe_ver'] || opts[:pe_ver_win]
        filename = "puppet-enterprise-#{version}"
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
          on host, "cd #{host['working_dir']}; curl -O #{path}/#{filename}#{extension}"
        end
      end

      #Determine the PE package to download/upload on a unix style host, download/upload that package onto the host
      #and unpack it.
      # @param [Host] host The unix style host to download/upload and unpack PE onto
      # @param  [Hash{Symbol=>Symbol, String}] opts The options
      # @option opts [String] :pe_dir Default directory or URL to pull PE package from
      #                  (Otherwise uses individual hosts pe_dir)
      # @api private
      def fetch_puppet_on_unix(host, opts)
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
          extension = link_exists?("#{path}/#{filename}.tar.gz") ? ".tar.gz" : ".tar"
          if not link_exists?("#{path}/#{filename}#{extension}")
            raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
          end
          unpack = 'tar -xvf -'
          unpack = extension =~ /gz/ ? 'gunzip | ' + unpack  : unpack

          on host, "cd #{host['working_dir']}; curl #{path}/#{filename}#{extension} | #{unpack}"
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
      # @api private
      def fetch_puppet(hosts, opts)
        hosts.each do |host|
          # We install Puppet from the master for frictionless installs, so we don't need to *fetch* anything
          next if host['roles'].include? 'frictionless' and ! version_is_less(opts[:pe_ver] || host['pe_ver'], '3.2.0')

          if host['platform'] =~ /windows/
            fetch_puppet_on_windows(host, opts)
          elsif host['platform'] =~ /osx/
            fetch_puppet_on_mac(host, opts)
          else
            fetch_puppet_on_unix(host, opts)
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
        on dashboard, "cd /opt/puppet/share/puppet-dashboard && /opt/puppet/bin/bundle exec /opt/puppet/bin/rake node:addclass[#{master},#{klass}]"
        on master, "puppet agent -t", :acceptable_exit_codes => [0,2]
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
      # @option opts [Hash<String>] :answers Pre-set answers based upon ENV vars and defaults
      #                             (See {Beaker::Options::Presets.env_vars})
      #
      # @example
      #  do_install(hosts, {:type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win =>  version_win})
      #
      # @api private
      #
      def do_install hosts, opts = {}
        opts[:type] = opts[:type] || :install
        hostcert='uname | grep -i sunos > /dev/null && hostname || hostname -s'
        master_certname = on(master, hostcert).stdout.strip
        pre30database = version_is_less(opts[:pe_ver] || database['pe_ver'], '3.0')
        pre30master = version_is_less(opts[:pe_ver] || master['pe_ver'], '3.0')

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
          end
          host['working_dir'] = host.tmpdir(Time.new.strftime("%Y-%m-%d_%H.%M.%S"))
        end

        fetch_puppet(hosts, opts)

        # If we're installing a database version less than 3.0, ignore the database host
        install_hosts = hosts.dup
        install_hosts.delete(database) if pre30database and database != master and database != dashboard

        install_hosts.each do |host|
          if host['platform'] =~ /windows/
            on host, installer_cmd(host, opts)
          elsif host['platform'] =~ /osx/
            on host, installer_cmd(host, opts)
            #set the certname and master
            on host, puppet("config set server #{master}")
            on host, puppet("config set certname #{host}")
            #run once to request cert
            on host, puppet_agent('-t'), :acceptable_exit_codes => [1]
          else
            # We only need answers if we're using the classic installer
            version = host['pe_ver'] || opts[:pe_ver]
            if (! host['roles'].include? 'frictionless') || version_is_less(version, '3.2.0')
              answers = Beaker::Answers.answers(opts[:pe_ver] || host['pe_ver'], hosts, master_certname, opts)
              create_remote_file host, "#{host['working_dir']}/answers", Beaker::Answers.answer_string(host, answers)
            else
              # If We're *not* running the classic installer, we want
              # to make sure the master has packages for us.
              deploy_frictionless_to_master(host)
            end

            on host, installer_cmd(host, opts)
          end

          # On each agent, we ensure the certificate is signed then shut down the agent
          sign_certificate_for(host)
          stop_agent_on(host)
        end

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

      #Perform a Puppet Enterprise Higgs install up until web browser interaction is required, runs on linux hosts only.
      # @param [Host] host The host to install higgs on
      # @param  [Hash{Symbol=>Symbol, String}] opts The options
      # @option opts [String] :pe_dir Default directory or URL to pull PE package from
      #                  (Otherwise uses individual hosts pe_dir)
      # @option opts [String] :pe_ver Default PE version to install 
      #                  (Otherwise uses individual hosts pe_ver)
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

        fetch_puppet([host], opts)

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
          res = on host, "cd #{host['working_dir']}/#{host['dist']} && cat #{host['higgs_file']}", :acceptable_exit_codes => (0..255)
          attempts += 1
          sleep( cur_sleep )
          prev_sleep = cur_sleep
          cur_sleep = cur_sleep + prev_sleep
        end

        if attempts >= tries
          raise "Failed to kick off PE (Higgs) web installation"
        end

      end

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
        special_nodes = [master, database, dashboard].uniq
        real_agents = agents - special_nodes
        special_nodes + real_agents
      end

      #Install FOSS based upon host configuration and options
      # @example will install puppet 3.6.1 from native puppetlabs provided packages wherever possible and will fail over to gem installation when impossible
      #  install_puppet({
      #    :version          => '3.6.1',
      #    :facter_version   => '2.0.1',
      #    :hiera_version    => '1.3.3',
      #    :default_action   => 'gem_install',
      #
      #   })
      #
      #
      # @example Will install latest packages on Enterprise Linux and Debian based distros and fail hard on all othere platforms.
      #  install_puppet()
      #
      # @note This will attempt to add a repository for apt.puppetlabs.com on
      #       Debian or Ubuntu machines, or yum.puppetlabs.com on EL or Fedora
      #       machines, then install the package 'puppet'.
      # @param [Hash{Symbol=>String}] opts
      # @option opts [String] :version Version of puppet to download
      # @option opts [String] :mac_download_url Url to download msi pattern of %url%/puppet-%version%.msi
      # @option opts [String] :win_download_url Url to download dmg  pattern of %url%/(puppet|hiera|facter)-%version%.msi
      #
      # @api dsl
      # @return nil
      # @raise [StandardError] When encountering an unsupported platform by default, or if gem cannot be found when default_action => 'gem_install'
      # @raise [FailTest] When error occurs during the actual installation process
      def install_puppet(opts = {})
        default_download_url = 'http://downloads.puppetlabs.com'
        opts = {:win_download_url => "#{default_download_url}/windows",
                :mac_download_url => "#{default_download_url}/mac"}.merge(opts)
        hosts.each do |host|
          if host['platform'] =~ /el-(5|6|7)/
            relver = $1
            install_puppet_from_rpm host, opts.merge(:release => relver, :family => 'el')
          elsif host['platform'] =~ /fedora-(\d+)/
            relver = $1
            install_puppet_from_rpm host, opts.merge(:release => relver, :family => 'fedora')
          elsif host['platform'] =~ /(ubuntu|debian)/
            install_puppet_from_deb host, opts
          elsif host['platform'] =~ /windows/
            relver = opts[:version]
            install_puppet_from_msi host, opts
          elsif host['platform'] =~ /osx/
            install_puppet_from_dmg host, opts
          else
            if opts[:default_action] == 'gem_install'
              install_puppet_from_gem host, opts
            else
              raise "install_puppet() called for unsupported platform '#{host['platform']}' on '#{host.name}'"
            end
          end

          # Certain install paths may not create the config dirs/files needed
          on host, "mkdir -p #{host['puppetpath']}"
          on host, "echo '' >> #{host['hieraconf']}"
        end
        nil
      end

      # Installs Puppet and dependencies using rpm
      #
      # @param [Host] host The host to install packages on
      # @param [Hash{Symbol=>String}] opts An options hash
      # @option opts [String] :version The version of Puppet to install, if nil installs latest version
      # @option opts [String] :facter_version The version of Facter to install, if nil installs latest version
      # @option opts [String] :hiera_version The version of Hiera to install, if nil installs latest version
      # @option opts [String] :default_action What to do if we don't know how to install native packages on host.
      #                                       Valid value is 'gem_install' or nil. If nil raises an exception when
      #                                       on an unsupported platform. When 'gem_install' attempts to install
      #                                       Puppet via gem.
      # @option opts [String] :release The major release of the OS
      # @option opts [String] :family The OS family (one of 'el' or 'fedora')
      # 
      # @return nil
      # @api private
      def install_puppet_from_rpm( host, opts )
        release_package_string = "http://yum.puppetlabs.com/puppetlabs-release-#{opts[:family]}-#{opts[:release]}.noarch.rpm"

        on host, "rpm -ivh #{release_package_string}"

        if opts[:facter_version]
          on host, "yum install -y facter-#{opts[:facter_version]}"
        end

        if opts[:hiera_version]
          on host, "yum install -y hiera-#{opts[:hiera_version]}"
        end

        puppet_pkg = opts[:version] ? "puppet-#{opts[:version]}" : 'puppet'
        on host, "yum install -y #{puppet_pkg}"
      end

      # Installs Puppet and dependencies from deb
      #
      # @param [Host] host The host to install packages on
      # @param [Hash{Symbol=>String}] opts An options hash
      # @option opts [String] :version The version of Puppet to install, if nil installs latest version
      # @option opts [String] :facter_version The version of Facter to install, if nil installs latest version
      # @option opts [String] :hiera_version The version of Hiera to install, if nil installs latest version
      # 
      # @return nil
      # @api private
      def install_puppet_from_deb( host, opts )
        if ! host.check_for_package 'lsb-release'
          host.install_package('lsb-release')
        end

        if ! host.check_for_command 'curl'
          on host, 'apt-get install -y curl'
        end

        on host, 'curl -O http://apt.puppetlabs.com/puppetlabs-release-$(lsb_release -c -s).deb'
        on host, 'dpkg -i puppetlabs-release-$(lsb_release -c -s).deb'
        on host, 'apt-get update'

        if opts[:facter_version]
          on host, "apt-get install -y facter=#{opts[:facter_version]}-1puppetlabs1"
        end

        if opts[:hiera_version]
          on host, "apt-get install -y hiera=#{opts[:hiera_version]}-1puppetlabs1"
        end

        if opts[:version]
          on host, "apt-get install -y puppet-common=#{opts[:version]}-1puppetlabs1"
          on host, "apt-get install -y puppet=#{opts[:version]}-1puppetlabs1"
        else
          on host, 'apt-get install -y puppet'
        end
      end

      # Installs Puppet and dependencies from msi
      #
      # @param [Host] host The host to install packages on
      # @param [Hash{Symbol=>String}] opts An options hash
      # @option opts [String] :version The version of Puppet to install, required
      # @option opts [String] :win_download_url The url to download puppet from
      # 
      # @return nil
      # @api private
      def install_puppet_from_msi( host, opts )
        on host, "curl -O #{opts[:win_download_url]}/puppet-#{opts[:version]}.msi"
        on host, "msiexec /qn /i puppet-#{opts[:version]}.msi"

        #Because the msi installer doesn't add Puppet to the environment path
        if fact_on(host, 'architecture').eql?('x86_64')
          install_dir = '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin'
        else
          install_dir = '/cygdrive/c/Program Files/Puppet Labs/Puppet/bin'
        end
        on host, %Q{ echo 'export PATH=$PATH:"#{install_dir}"' > /etc/bash.bashrc }
      end

      # Installs Puppet and dependencies from dmg
      #
      # @param [Host] host The host to install packages on
      # @param [Hash{Symbol=>String}] opts An options hash
      # @option opts [String] :version The version of Puppet to install, required
      # @option opts [String] :facter_version The version of Facter to install, required
      # @option opts [String] :hiera_version The version of Hiera to install, required
      # 
      # @return nil
      # @api private
      def install_puppet_from_dmg( host, opts )
        puppet_ver = opts[:version]
        facter_ver = opts[:facter_version]
        hiera_ver = opts[:hiera_version]

        on host, "curl -O #{opts[:mac_download_url]}/puppet-#{puppet_ver}.dmg"
        on host, "curl -O #{opts[:mac_download_url]}/facter-#{facter_ver}.dmg"
        on host, "curl -O #{opts[:mac_download_url]}/hiera-#{hiera_ver}.dmg"

        on host, "hdiutil attach puppet-#{puppet_ver}.dmg"
        on host, "hdiutil attach facter-#{facter_ver}.dmg"
        on host, "hdiutil attach hiera-#{hiera_ver}.dmg"

        on host, "installer -pkg /Volumes/puppet-#{puppet_ver}/puppet-#{puppet_ver}.pkg -target /"
        on host, "installer -pkg /Volumes/facter-#{facter_ver}/facter-#{facter_ver}.pkg -target /"
        on host, "installer -pkg /Volumes/hiera-#{hiera_ver}/hiera-#{hiera_ver}.pkg -target /"
      end

      # Installs Puppet and dependencies from gem
      #
      # @param [Host] host The host to install packages on
      # @param [Hash{Symbol=>String}] opts An options hash
      # @option opts [String] :version The version of Puppet to install, if nil installs latest
      # @option opts [String] :facter_version The version of Facter to install, if nil installs latest
      # @option opts [String] :hiera_version The version of Hiera to install, if nil installs latest
      # 
      # @return nil
      # @raise [StandardError] if gem does not exist on target host
      # @api private
      def install_puppet_from_gem( host, opts )
        # Hosts may be provisioned with csw but pkgutil won't be in the
        # PATH by default to avoid changing the behavior for Puppet's tests
        if host['platform'] =~ /solaris-10/
          on host, 'ln -s /opt/csw/bin/pkgutil /usr/bin/pkgutil'
        end

        # Solaris doesn't necessarily have this, but gem needs it
        if host['platform'] =~ /solaris/
          on host, 'mkdir -p /var/lib' 
        end

        unless host.check_for_command( 'gem' )
          gempkg = case host['platform']
                   when /solaris-11/                   then 'ruby-18'
                   when /ubuntu-14/                    then 'ruby'
                   when /solaris-10|ubuntu|debian|el-/ then 'rubygems'
                   else
                     raise "install_puppet() called with default_action " +
                           "'gem_install' but program `gem' is " +
                           "not installed on #{host.name}"
                   end

          host.install_package gempkg
        end

        if host['platform'] =~ /debian|ubuntu|solaris/
          gem_env = YAML.load( on( host, 'gem environment' ).stdout )
          gem_paths_array = gem_env['RubyGems Environment'].find {|h| h['GEM PATHS'] != nil }['GEM PATHS']
          path_with_gem = 'export PATH=' + gem_paths_array.join(':') + ':${PATH}'
          on host, "echo '#{path_with_gem}' >> ~/.bashrc"
        end

        if opts[:facter_version]
          on host, "gem install facter -v#{opts[:facter_version]} --no-ri --no-rdoc"
        end

        if opts[:hiera_version]
          on host, "gem install hiera -v#{opts[:hiera_version]} --no-ri --no-rdoc"
        end

        ver_cmd = opts[:version] ? "-v#{opts[:version]}" : ''
        on host, "gem install puppet #{ver_cmd} --no-ri --no-rdoc"
      end


      #Install PE based upon host configuration and options
      # @example
      #  install_pe
      #
      # @note Either pe_ver and pe_dir should be set in the ENV or each host should have pe_ver and pe_dir set individually.
      #       Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz)
      #       for Unix like systems and puppet-enterprise-VERSION.msi for Windows systems.
      #
      # @api dsl
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
      # @api dsl
      def upgrade_pe path=nil
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
        #send in the global options hash
        do_install(sorted_hosts, options.merge({:type => :upgrade}))
        options['upgrade'] = true
      end

      # Install official puppetlabs release repository configuration on host.
      #
      # @param [Host] host An object implementing {Beaker::Hosts}'s
      #                    interface.
      #
      # @note This method only works on redhat-like and debian-like hosts.
      #
      def install_puppetlabs_release_repo ( host )
        variant, version, arch, codename = host['platform'].to_array

        case variant
        when /^(fedora|el|centos)$/
          variant = (($1 == 'centos') ? 'el' : $1)

          rpm = options[:release_yum_repo_url] +
            "/puppetlabs-release-%s-%s.noarch.rpm" % [variant, version]

          on host, "rpm -ivh --force #{rpm}"

        when /^(debian|ubuntu)$/
          deb = URI.join(options[:release_apt_repo_url],  "puppetlabs-release-%s.deb" % codename)

          on host, "wget -O /tmp/puppet.deb #{deb}"
          on host, "dpkg -i --force-all /tmp/puppet.deb"
          on host, "apt-get update"
        else
          raise "No repository installation step for #{variant} yet..."
        end
      end

      # Install development repository on the given host. This method pushes all
      # repository information including package files for the specified
      # package_name to the host and modifies the repository configuration file
      # to point at the new repository. This is particularly useful for
      # installing development packages on hosts that can't access the builds
      # server.
      #
      # @param [Host] host An object implementing {Beaker::Hosts}'s
      #                    interface.
      # @param [String] package_name The name of the package whose repository is
      #                              being installed.
      # @param [String] build_version A string identifying the output of a
      #                               packaging job for use in looking up
      #                               repository directory information
      # @param [String] repo_configs_dir A local directory where repository files will be
      #                                  stored as an intermediate step before
      #                                  pushing them to the given host.
      #
      # @note This method only works on redhat-like and debian-like hosts.
      #
      def install_puppetlabs_dev_repo ( host, package_name, build_version,
                                repo_configs_dir = 'tmp/repo_configs' )
        variant, version, arch, codename = host['platform'].to_array
        platform_configs_dir = File.join(repo_configs_dir, variant)

        # some of the uses of dev_builds_url below can't include protocol info,
        # pluse this opens up possibility of switching the behavior on provided
        # url type
        _, protocol, hostname = options[:dev_builds_url].partition /.*:\/\//
        dev_builds_url = protocol + hostname

        on host, "mkdir -p /root/#{package_name}"

        case variant
        when /^(fedora|el|centos)$/
          variant = (($1 == 'centos') ? 'el' : $1)
          fedora_prefix = ((variant == 'fedora') ? 'f' : '')

          if host.is_pe?
            pattern = "pl-%s-%s-repos-pe-%s-%s%s-%s.repo"
          else
            pattern = "pl-%s-%s-%s-%s%s-%s.repo"
          end

          repo_filename = pattern % [
            package_name,
            build_version,
            variant,
            fedora_prefix,
            version,
            arch
          ]

          repo = fetch_http_file( "%s/%s/%s/repo_configs/rpm/" %
                       [ dev_builds_url, package_name, build_version ],
                        repo_filename,
                        platform_configs_dir)

          link = "%s/%s/%s/repos/%s/%s%s/products/%s/" %
            [ dev_builds_url, package_name, build_version, variant,
              fedora_prefix, version, arch ]

          if not link_exists?( link )
            link = "%s/%s/%s/repos/%s/%s%s/devel/%s/" %
              [ dev_builds_url, package_name, build_version, variant,
                fedora_prefix, version, arch ]
          end

          if not link_exists?( link )
            raise "Unable to reach a repo directory at #{link}"
          end

          repo_dir = fetch_http_dir( link, platform_configs_dir )

          config_dir = '/etc/yum.repos.d/'
          scp_to host, repo, config_dir
          scp_to host, repo_dir, "/root/#{package_name}"

          search = "baseurl\\s*=\\s*http:\\/\\/#{hostname}.*$"
          replace = "baseurl=file:\\/\\/\\/root\\/#{package_name}\\/#{arch}"
          sed_command = "sed -i 's/#{search}/#{replace}/'"
          find_and_sed = "find #{config_dir} -name \"*.repo\" -exec #{sed_command} {} \\;"

          on host, find_and_sed

        when /^(debian|ubuntu)$/
          list = fetch_http_file( "%s/%s/%s/repo_configs/deb/" %
                         [ dev_builds_url, package_name, build_version ],
                        "pl-%s-%s-%s.list" %
                         [ package_name, build_version, codename ],
                        platform_configs_dir )

          repo_dir = fetch_http_dir( "%s/%s/%s/repos/apt/%s" %
                                      [ dev_builds_url, package_name,
                                        build_version, codename ],
                                       platform_configs_dir )

          config_dir = '/etc/apt/sources.list.d'
          scp_to host, list, config_dir
          scp_to host, repo_dir, "/root/#{package_name}"

          search = "deb\\s\\+http:\\/\\/#{hostname}.*$"
          replace = "deb file:\\/\\/\\/root\\/#{package_name}\\/#{codename} #{codename} main"
          sed_command = "sed -i 's/#{search}/#{replace}/'"
          find_and_sed = "find #{config_dir} -name \"*.list\" -exec #{sed_command} {} \\;"

          on host, find_and_sed
          on host, "apt-get update"

        else
          raise "No repository installation step for #{variant} yet..."
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
      # @api dsl
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

    end
  end
end
