require 'pathname'

module Beaker
  module DSL
    #
    # This module contains methods to help cloning, extracting git info,
    # ordering of Puppet packages, and installing ruby projects that
    # contain an `install.rb` script.
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
      # @param [Hash{Symbol=>String}] options The options
      # @option options [String] :installer The name of the installer to use for upgrading/installing
      # @option options [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
      #                          (Othersie uses individual Windows hosts pe_ver)
      # @option options [String  :pe_ver Default PE version to install or upgrade to
      #                          (Otherwise uses individual hosts pe_ver)
      # @example
      #      on host, "#{installer_cmd(host, options)} -a #{host['working_dir']}/answers"
      # @api private
      def installer_cmd(host, options)
        if host['platform'] =~ /windows/
          version = options[:pe_ver_win] || host['pe_ver']
          "cd #{host['working_dir']} && msiexec.exe /qn /i puppet-enterprise-#{version}.msi"
        elsif host['roles'].include? 'frictionless'
          version = options[:pe_ver] || host['pe_ver']
          "cd #{host['working_dir']} && curl -kO https://#{master}:8140/packages/#{version}/#{host['platform']}.bash && bash #{host['platform']}.bash"
        else
          "cd #{host['working_dir']}/#{host['dist']} && ./#{options[:installer]} -a #{host['working_dir']}/answers"
        end
      end

      #Determine is a given URL is accessible 
      #@param [String] link The URL to examine
      #@return [Boolean] true if the URL has a '200' HTTP response code, false otherwise
      #@example
      #  extension = link_exists?("#{URL}.tar.gz") ? ".tar.gz" : ".tar"
      # @api private
      def link_exists?(link)
        require "net/http"
        require "open-uri"
        url = URI.parse(link)
        Net::HTTP.start(url.host, url.port) do |http|
          return http.head(url.request_uri).code == "200"
        end
      end

      #Determine the PE package to download/upload per-host, download/upload that package onto the host 
      #and unpack it.
      # @param [Array<Host>] hosts The hosts to download/upload and unpack PE onto 
      # @param  [Hash{Symbol=>Symbol, String}] options The options
      # @option options [String] :pe_dir Default directory or URL to pull PE package from 
      #                  (Otherwise uses individual hosts pe_dir)
      # @option options [String] :pe_ver Default PE version to install or upgrade to
      #                  (Otherwise uses individual hosts pe_ver)
      # @option options [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
      #                  (Otherwise uses individual Windows hosts pe_ver)
      # @api private
      def fetch_puppet(hosts, options)
        hosts.each do |host|
          # We install Puppet from the master for frictionless installs, so we don't need to *fetch* anything
          next if host['roles'].include? 'frictionless'

          windows = host['platform'] =~ /windows/
          path = options[:pe_dir] || host['pe_dir']
          local = File.directory?(path)
          filename = ""
          extension = ""
          if windows
            version = options[:pe_ver_win] || host['pe_ver']
            filename = "puppet-enterprise-#{version}"
            extension = ".msi"
          else
            filename = "#{host['dist']}"
            extension = ""
            if local
              extension = File.exists?("#{path}/#{filename}.tar.gz") ? ".tar.gz" : ".tar"
            else
              extension = link_exists?("#{path}/#{filename}.tar.gz") ? ".tar.gz" : ".tar"
            end
          end
          if local
             if not File.exists?("#{path}/#{filename}#{extension}")
               raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist" 
             end
             scp_to host, "#{path}/#{filename}#{extension}", "#{host['working_dir']}/#{filename}#{extension}"
          else
             if not link_exists?("#{path}/#{filename}#{extension}")
               raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist" 
             end
             on host, "cd #{host['working_dir']}; curl #{path}/#{filename}#{extension} -o #{filename}#{extension}"
          end
          if extension =~ /gz/
            on host, "cd #{host['working_dir']}; gunzip #{filename}#{extension}"
          end
          if extension =~ /tar/
            on host, "cd #{host['working_dir']}; tar -xvf #{filename}.tar"
          end
        end
      end

      #Perform a Puppet Enterprise upgrade or install
      # @param [Array<Host>] hosts The hosts to install or upgrade PE on 
      # @param  [Hash{Symbol=>Symbol, String}] options The options
      # @option options [String] :pe_dir Default directory or URL to pull PE package from 
      #                  (Otherwise uses individual hosts pe_dir)
      # @option options [String] :pe_ver Default PE version to install or upgrade to
      #                  (Otherwise uses individual hosts pe_ver)
      # @option options [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
      #                  (Otherwise uses individual Windows hosts pe_ver)
      # @option options [String] :installer ('puppet-enterprise-installer') The name of the installer to use for upgrading/installing
      # @option options [Symbol] :type (:install) One of :upgrade or :install
      #
      #                      
      # @example 
      #  do_install(hosts, {:type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win =>  version_win})
      #
      # @api private
      #
      def do_install hosts, options = {}
        options[:installer] = options[:installer] || 'puppet-enterprise-installer' 
        options[:type] = options[:type] || :install 
        hostcert='uname | grep -i sunos > /dev/null && hostname || hostname -s'
        master_certname = on(master, hostcert).stdout.strip
        pre30database = version_is_less(options[:pe_ver] || database['pe_ver'], '3.0')
        pre30master = version_is_less(options[:pe_ver] || master['pe_ver'], '3.0')

        # Set PE distribution for all the hosts, create working dir
        use_all_tar = ENV['PE_USE_ALL_TAR'] == 'true'
        hosts.each do |host|
          if host['platform'] !~ /windows/
            platform = use_all_tar ? 'all' : host['platform']
            version = options[:pe_ver] || host['pe_ver']
            host['dist'] = "puppet-enterprise-#{version}-#{platform}"
          end
          host['working_dir'] = "/tmp/" + Time.new.strftime("%Y-%m-%d_%H.%M.%S") #unique working dirs make me happy
          on host, "mkdir #{host['working_dir']}"
        end

        fetch_puppet(hosts, options)

        hosts.each do |host|
          # Database host was added in 3.0. Skip it if installing an older version
          next if host == database and host != master and host != dashboard and pre30database
          if host['platform'] =~ /windows/
            on host, "#{installer_cmd(host, options)} PUPPET_MASTER_SERVER=#{master} PUPPET_AGENT_CERTNAME=#{host}"
          else
            # We only need answers if we're using the classic installer
            if ! host['roles'].include? 'frictionless'
              answers = Beaker::Answers.answers(options[:pe_ver] || host['pe_ver'], hosts, master_certname, options)
              create_remote_file host, "#{host['working_dir']}/answers", Beaker::Answers.answer_string(host, answers)
            end

            on host, installer_cmd(host, options)
          end
        end


        # If we're installing a database version less than 3.0, ignore the database host
        install_hosts = hosts.dup
        install_hosts.delete(database) if pre30database and database != master and database != dashboard

        # On each agent, we ensure the certificate is signed then shut down the agent
        install_hosts.each do |host|
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

      #Is PE version a less than PE version b
      #@param [String] a A PE version of the from '\d.\d.\d.*'
      #@param [String] b A PE version of the form '\d.\d.\d.*'
      #@return [Boolean] true if a is less than b, otherwise return false
      #
      #@note 3.0.0-160-gac44cfb is greater than 3.0.0, and 2.8.2
      # @!visibility private
      def version_is_less a, b
        a_nums = a.split('-')[0].split('.')
        b_nums = b.split('-')[0].split('.')
        (0...a_nums.length).each do |i|
          if i < b_nums.length
            if a_nums[i] < b_nums[i] 
              return true
            elsif a_nums[i] > b_nums[i]
              return false
            end
          else
            return false
          end
        end
        #checks all dots, they are equal so examine the rest
        a_rest = a.split('-', 2)[1]
        b_rest = b.split('-', 2)[1]
        if a_rest and b_rest and a_rest < b_rest 
          return false
        elsif a_rest and not b_rest
          return false
        elsif not a_rest and b_rest
          return true
        end
        return false
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
          if host['platform'] =~ /windows/
            host['pe_ver'] = host['pe_ver'] || 
              Beaker::Options::PEVersionScraper.load_pe_version(host[:pe_dir] || options[:pe_dir], options[:pe_version_file_win])
          else
            host['pe_ver'] = host['pe_ver'] || 
              Beaker::Options::PEVersionScraper.load_pe_version(host[:pe_dir] || options[:pe_dir], options[:pe_version_file])
          end
        end
        do_install sorted_hosts
      end

      #Upgrade PE based upon host configuration and options
      # @param [String] path A path (either local directory or a URL to a listing of PE builds). 
      #                      Will contain a LATEST file indicating the latest build to install.
      # @example 
      #  upgrade_pe("http://neptune.puppetlabs.lan/3.0/ci-ready/")
      #
      # @note Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz)
      #       for Unix like systems and puppet-enterprise-VERSION.msi for Windows systems.
      # @api dsl
      def upgrade_pe path 
        version = Options::PEVersionScraper.load_pe_version(path, options[:pe_version_file])
        version_win = Options::PEVersionScraper.load_pe_version(path, options[:pe_version_file_win])
        pre_30 = version_is_less(version, '3.0')
        if pre_30
          do_install(sorted_hosts, {:type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win => version_win, :installer => 'puppet-enterprise-upgrader'})
        else
          do_install(sorted_hosts, {:type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win =>  version_win})
        end
        #at this point we've completed a successful upgrade, update the host pe_ver to reflect that
        hosts.each do |host|
          if host['platform'] =~ /windows/
            host['pe_ver'] = version_win
          else
            host['pe_ver'] = version
          end
        end
      end

    end
  end
end
