[ 'aio_defaults', 'foss_defaults', 'puppet_utils', 'windows_utils' ].each do |lib|
    require "beaker/dsl/install_utils/#{lib}"
end
module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains methods to install FOSS puppet from various sources
      #
      # To mix this is into a class you need the following:
      # * a method *hosts* that yields any hosts implementing
      #   {Beaker::Host}'s interface to act upon.
      # * a method *options* that provides an options hash, see {Beaker::Options::OptionsHash}
      # * the module {Beaker::DSL::Roles} that provides access to the various hosts implementing
      #   {Beaker::Host}'s interface to act upon
      # * the module {Beaker::DSL::Wrappers} the provides convenience methods for {Beaker::DSL::Command} creation
      module FOSSUtils
        include AIODefaults
        include FOSSDefaults
        include PuppetUtils
        include WindowsUtils

        # The default install path
        SourcePath  = "/opt/puppet-git-repos"

        # A regex to know if the uri passed is pointing to a git repo
        GitURI       = %r{^(git|https?|file)://|^git@|^gitmirror@}

        # Github's ssh signature for cloning via ssh
        GitHubSig   = 'github.com,207.97.227.239 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=='

        # lookup project-specific git environment variables
        # PROJECT_VAR or VAR otherwise return the default
        #
        # @!visibility private
        def lookup_in_env(env_variable_name, project_name=nil, default=nil)
          env_variable_name     = "#{env_variable_name.upcase.gsub('-','_')}"
          project_specific_name = "#{project_name.upcase.gsub('-','_')}_#{env_variable_name}" if project_name
          project_name && ENV[project_specific_name] || ENV[env_variable_name] || default
        end

        # @param [String] project_name
        # @param [String] git_fork     When not provided will use PROJECT_FORK environment variable
        # @param [String] git_server   When not provided will use PROJECT_SERVER environment variable
        # @param [String] git_protocol 'git','ssh','https'
        #
        # @return [String] Returns a git-usable url
        #
        # TODO: enable other protocols, clarify, http://git-scm.com/book/ch4-1.html
        def build_git_url(project_name, git_fork = nil, git_server = nil, git_protocol='https')
          git_fork   ||= lookup_in_env('FORK',   project_name, 'puppetlabs')
          git_server ||= lookup_in_env('SERVER', project_name, 'github.com')

          case git_protocol
          when /(ssh|git)/
            git_protocol = 'git@'
          when /https/
            git_protocol = 'https://'
          end

          repo = (git_server == 'github.com') ? "#{git_fork}/#{project_name}.git" : "#{git_fork}-#{project_name}.git"
          return git_protocol == 'git@' ? "#{git_protocol}#{git_server}:#{repo}" : "#{git_protocol}#{git_server}/#{repo}"
        end
        alias_method :build_giturl, :build_git_url

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
        def extract_repo_info_from uri
          require 'pathname'
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
        #       * {Beaker::DSL::Helpers#on}
        #
        def find_git_repo_versions host, path, repository
          logger.notify("\n  * Grab version for #{repository[:name]}")

          version = {}
          on host, "cd #{path}/#{repository[:name]} && " +
                    "git describe || true" do
            version[repository[:name]] = stdout.chomp
          end

          version
        end

        # @param [Host] host An object implementing {Beaker::Hosts}'s
        #                    interface.
        # @param [String] path The path on the remote [host] to the repository
        # @param [Hash{Symbol=>String}] repository A hash representing repo
        #                                          info like that emitted by
        #                                          {#extract_repo_info_from}
        #
        # @note This requires the helper methods:
        #       * {Beaker::DSL::Helpers#on}
        #
        def clone_git_repo_on host, path, repository, opts = {}
          opts = {:accept_all_exit_codes => true}.merge(opts)
          name          = repository[:name]
          repo          = repository[:path]
          rev           = repository[:rev]
          depth         = repository[:depth]
          depth_branch  = repository[:depth_branch]
          target        = "#{path}/#{name}"

          if (depth_branch.nil?)
            depth_branch = rev
          end

          clone_cmd = "git clone #{repo} #{target}"
          if (depth)
            clone_cmd = "git clone --branch #{depth_branch} --depth #{depth} #{repo} #{target}"
          end

          logger.notify("\n  * Clone #{repo} if needed")

          on host, "test -d #{path} || mkdir -p #{path}", opts
          on host, "test -d #{target} || #{clone_cmd}", opts

          logger.notify("\n  * Update #{name} and check out revision #{rev}")
          commands = ["cd #{target}",
                      "remote rm origin",
                      "remote add origin #{repo}",
                      "fetch origin +refs/pull/*:refs/remotes/origin/pr/* +refs/heads/*:refs/remotes/origin/*",
                      "clean -fdx",
                      "checkout -f #{rev}"]
          on host, commands.join(" && git "), opts
        end

        # @see #find_git_repo_versions
        # @note This assumes the target repository application
        #   can be installed via an install.rb ruby script.
        def install_from_git_on host, path, repository, opts = {}
          opts = {:accept_all_exit_codes => true}.merge(opts)
          clone_git_repo_on host, path, repository, opts
          name          = repository[:name]
          logger.notify("\n  * Install #{name} on the system")
          # The solaris ruby IPS package has bindir set to /usr/ruby/1.8/bin.
          # However, this is not the path to which we want to deliver our
          # binaries. So if we are using solaris, we have to pass the bin and
          # sbin directories to the install.rb
          target        = "#{path}/#{name}"
          install_opts = ''
          install_opts = '--bindir=/usr/bin --sbindir=/usr/sbin' if host['platform'].include? 'solaris'

          on host,  "cd #{target} && " +
                    "if [ -f install.rb ]; then " +
                    "ruby ./install.rb #{install_opts}; " +
                    "else true; fi", opts
        end
        alias_method :install_from_git, :install_from_git_on

        # @deprecated Use {#install_puppet_on} instead.
        def install_puppet(opts = {})
          #send in the global hosts!
          install_puppet_on(hosts, opts)
        end

        #Install FOSS based on specified hosts using provided options
        # @example will install puppet 3.6.1 from native puppetlabs provided packages wherever possible and will fail over to gem installation when impossible
        #  install_puppet_on(hosts, {
        #    :version          => '3.6.1',
        #    :facter_version   => '2.0.1',
        #    :hiera_version    => '1.3.3',
        #    :default_action   => 'gem_install',
        #   })
        #
        # @example will install puppet 4 from native puppetlabs provided puppet-agent 1.x package wherever possible and will fail over to gem installation when impossible
        #   install_puppet({
        #     :version              => '4',
        #     :default_action       => 'gem_install'
        #   })
        #
        # @example will install puppet 4.1.0 from native puppetlabs provided puppet-agent 1.1.0 package wherever possible and will fail over to gem installation when impossible
        #   install_puppet({
        #     :version              => '4.1.0',
        #     :puppet_agent_version => '1.1.0',
        #     :default_action       => 'gem_install'
        #   })
        #
        #
        #
        # @example Will install latest packages on Enterprise Linux and Debian based distros and fail hard on all othere platforms.
        #  install_puppet_on(hosts)
        #
        # @note This will attempt to add a repository for apt.puppetlabs.com on
        #       Debian, Ubuntu, or Cumulus machines, or yum.puppetlabs.com on EL or Fedora
        #       machines, then install the package 'puppet' or 'puppet-agent'.
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts
        # @option opts [String] :version Version of puppet to download
        # @option opts [String] :puppet_agent_version Version of puppet agent to download
        # @option opts [String] :mac_download_url Url to download msi pattern of %url%/puppet-%version%.msi
        # @option opts [String] :win_download_url Url to download dmg pattern of %url%/(puppet|hiera|facter)-%version%.msi
        # @option opts [Boolean] :run_in_parallel   Whether to install on all hosts in parallel. Defaults to false.
        #
        # @return nil
        # @raise [StandardError] When encountering an unsupported platform by default, or if gem cannot be found when default_action => 'gem_install'
        # @raise [FailTest] When error occurs during the actual installation process
        def install_puppet_on(hosts, opts={})
          opts = FOSS_DEFAULT_DOWNLOAD_URLS.merge(opts)

          # If version isn't specified assume the latest in the 3.x series
          if opts[:version] and not version_is_less(opts[:version], '4.0.0')
            # backwards compatability
            opts[:puppet_agent_version] ||= opts[:version]
            install_puppet_agent_on(hosts, opts)
          else
            # Use option specified in the method call, otherwise check whether the global
            # run_in_parallel option includes install
            run_in_parallel = run_in_parallel? opts, @options, 'install'
            block_on hosts, { :run_in_parallel => run_in_parallel } do |host|
              if host['platform'] =~ /el-(5|6|7)/
                relver = $1
                install_puppet_from_rpm_on(host, opts.merge(:release => relver, :family => 'el'))
              elsif host['platform'] =~ /sles-(11|12)/
                relver = $1
                # Need to get rid of whatever Puppet might have shipped on the
                # upstream images
                host.uninstall_package('puppet')
                install_puppet_from_rpm_on(host, opts.merge(:release => relver, :family => 'sles'))
              elsif host['platform'] =~ /fedora-(\d+)/
                relver = $1
                install_puppet_from_rpm_on(host, opts.merge(:release => relver, :family => 'fedora'))
              elsif host['platform'] =~ /(ubuntu|debian|cumulus|huaweios)/
                install_puppet_from_deb_on(host, opts)
              elsif host['platform'] =~ /windows/
                relver = opts[:version]
                install_puppet_from_msi_on(host, opts)
              elsif host['platform'] =~ /osx/
                install_puppet_from_dmg_on(host, opts)
              elsif host['platform'] =~ /openbsd/
                install_puppet_from_openbsd_packages_on(host, opts)
              elsif host['platform'] =~ /freebsd/
                install_puppet_from_freebsd_ports_on(host, opts)
              else
                if opts[:default_action] == 'gem_install'
                  opts[:version] ||= '~> 3.x'
                  install_puppet_from_gem_on(host, opts)
                else
                  raise "install_puppet() called for unsupported platform '#{host['platform']}' on '#{host.name}'"
                end
              end

              host[:version] = opts[:version]

              # Certain install paths may not create the config dirs/files needed
              host.mkdir_p host['puppetpath'] unless host[:type] =~ /aio/

              if ((host['platform'] =~ /windows/) and not host.is_cygwin?)
                # Do nothing
              else
                on host, "echo '' >> #{host.puppet['hiera_config']}"
              end
            end
          end

          nil
        end

        #Install Puppet Agent based on specified hosts using provided options
        # @example will install puppet-agent 1.1.0 from native puppetlabs provided packages wherever possible and will fail over to gem installing latest puppet
        #  install_puppet_agent_on(hosts, {
        #    :puppet_agent_version          => '1.1.0',
        #    :default_action                => 'gem_install',
        #   })
        #
        #
        # @example Will install latest packages on Enterprise Linux, Debian based distros, Windows, OSX and fail hard on all othere platforms.
        #  install_puppet_agent_on(hosts)
        #
        # @note This will attempt to add a repository for apt.puppetlabs.com on
        #       Debian, Ubuntu, or Cumulus machines, or yum.puppetlabs.com on EL or Fedora
        #       machines, then install the package 'puppet-agent'.
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts
        # @option opts [String] :puppet_agent_version Version of puppet to download
        # @option opts [String] :puppet_gem_version Version of puppet to install via gem if no puppet-agent package is available
        # @option opts [String] :mac_download_url Url to download msi pattern of %url%/puppet-agent-%version%.msi
        # @option opts [String] :win_download_url Url to download dmg pattern of %url%/puppet-agent-%version%.msi
        # @option opts [String] :puppet_collection Defaults to 'pc1'
        # @option opts [Boolean] :run_in_parallel Whether to run on each host in parallel.
        #
        # @return nil
        # @raise [StandardError] When encountering an unsupported platform by default, or if gem cannot be found when default_action => 'gem_install'
        # @raise [FailTest] When error occurs during the actual installation process
        def install_puppet_agent_on(hosts, opts = {})
          opts = FOSS_DEFAULT_DOWNLOAD_URLS.merge(opts)
          opts[:puppet_collection] ||= 'pc1' #hi!  i'm case sensitive!  be careful!
          opts[:puppet_agent_version] ||= opts[:version] #backwards compatability with old parameter name

          run_in_parallel = run_in_parallel? opts, @options, 'install'
          block_on hosts, { :run_in_parallel => run_in_parallel } do |host|
            add_role(host, 'aio') #we are installing agent, so we want aio role
            package_name = nil
            case host['platform']
            when /el-|fedora|sles|centos|cisco_/
              package_name = 'puppet-agent'
              package_name << "-#{opts[:puppet_agent_version]}" if opts[:puppet_agent_version]
            when /debian|ubuntu|cumulus|huaweios/
              package_name = 'puppet-agent'
              package_name << "=#{opts[:puppet_agent_version]}-1#{host['platform'].codename}" if opts[:puppet_agent_version]
            when /windows/
              install_puppet_agent_from_msi_on(host, opts)
            when /osx/
              install_puppet_agent_from_dmg_on(host, opts)
            else
              if opts[:default_action] == 'gem_install'
                opts[:version] = opts[:puppet_gem_version]
                install_puppet_from_gem_on(host, opts)
                on host, "echo '' >> #{host.puppet['hiera_config']}"
              else
                raise "install_puppet_agent_on() called for unsupported " +
                      "platform '#{host['platform']}' on '#{host.name}'"
              end
            end

            if package_name
              install_puppetlabs_release_repo( host, opts[:puppet_collection] )
              host.install_package( package_name )
            end
          end
        end

        # @deprecated Use {#configure_puppet_on} instead.
        def configure_puppet(opts={})
          hosts.each do |host|
            configure_puppet_on(host,opts)
          end
        end

        # Configure puppet.conf on the given host(s) based upon a provided hash
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts
        # @option opts [Hash{String=>String}] :main configure the main section of puppet.conf
        # @option opts [Hash{String=>String}] :agent configure the agent section of puppet.conf
        # @option opts [Boolean] :run_in_parallel Whether to run on each host in parallel.
        #
        # @example will configure /etc/puppet.conf on the puppet master.
        #   config = {
        #     'main' => {
        #       'server'   => 'testbox.test.local',
        #       'certname' => 'testbox.test.local',
        #       'logdir'   => '/var/log/puppet',
        #       'vardir'   => '/var/lib/puppet',
        #       'ssldir'   => '/var/lib/puppet/ssl',
        #       'rundir'   => '/var/run/puppet'
        #     },
        #     'agent' => {
        #       'environment' => 'dev'
        #     }
        #   }
        #   configure_puppet_on(master, config)
        #
        # @return nil
        def configure_puppet_on(hosts, opts = {})
          puppet_conf_text = ''
          opts.each do |section,options|
            puppet_conf_text << "[#{section}]\n"
            options.each do |option,value|
              puppet_conf_text << "#{option}=#{value}\n"
            end
            puppet_conf_text << "\n"
          end
          logger.debug( "setting config '#{puppet_conf_text}' on hosts #{hosts}" )
          block_on hosts, opts do |host|
            puppet_conf_path = host.puppet['config']
            create_remote_file(host, puppet_conf_path, puppet_conf_text)
          end
        end

        # Installs Puppet and dependencies using rpm on provided host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install, if nil installs latest version
        # @option opts [String] :facter_version The version of Facter to install, if nil installs latest version
        # @option opts [String] :hiera_version The version of Hiera to install, if nil installs latest version
        # @option opts [String] :release The major release of the OS
        # @option opts [String] :family The OS family (one of 'el' or 'fedora')
        #
        # @return nil
        # @api private
        def install_puppet_from_rpm_on( hosts, opts )
          block_on hosts do |host|
            if host[:type] == 'aio'
              install_puppetlabs_release_repo(host,'pc1',opts)
              opts[:version] = 'agent' unless opts[:version]
            else
              install_puppetlabs_release_repo(host,nil,opts)
            end

            if opts[:facter_version]
              host.install_package("facter-#{opts[:facter_version]}")
            end

            if opts[:hiera_version]
              host.install_package("hiera-#{opts[:hiera_version]}")
            end

            puppet_pkg = opts[:version] ? "puppet-#{opts[:version]}" : 'puppet'
            host.install_package("#{puppet_pkg}")
            configure_type_defaults_on( host )
          end
        end
        alias_method :install_puppet_from_rpm, :install_puppet_from_rpm_on

        # Installs Puppet and dependencies from deb on provided host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install, if nil installs latest version
        # @option opts [String] :facter_version The version of Facter to install, if nil installs latest version
        # @option opts [String] :hiera_version The version of Hiera to install, if nil installs latest version
        #
        # @return nil
        # @api private
        def install_puppet_from_deb_on( hosts, opts )
          block_on hosts do |host|
            install_puppetlabs_release_repo(host)

            if opts[:facter_version]
              host.install_package("facter=#{opts[:facter_version]}-1puppetlabs1")
            end

            if opts[:hiera_version]
              host.install_package("hiera=#{opts[:hiera_version]}-1puppetlabs1")
            end

            if opts[:version]
              host.install_package("puppet-common=#{opts[:version]}-1puppetlabs1")
              host.install_package("puppet=#{opts[:version]}-1puppetlabs1")
            else
              host.install_package('puppet')
            end
            configure_type_defaults_on( host )
          end
        end
        alias_method :install_puppet_from_deb, :install_puppet_from_deb_on

        # Installs Puppet and dependencies from msi on provided host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install
        # @option opts [String] :puppet_agent_version The version of the
        #     puppet-agent package to install, required if version is 4.0.0 or greater
        # @option opts [String] :win_download_url The url to download puppet from
        #
        # @note on windows, the +:ruby_arch+ host parameter can determine in addition
        # to other settings whether the 32 or 64bit install is used
        def install_puppet_from_msi_on( hosts, opts )
          block_on hosts do |host|
            version = opts[:version]

            if version && !version_is_less(version, '4.0.0')
              if opts[:puppet_agent_version].nil?
                raise "You must specify the version of puppet agent you " +
                      "want to install if you want to install Puppet 4.0 " +
                      "or greater on Windows"
              end

              opts[:version] = opts[:puppet_agent_version]
              install_puppet_agent_from_msi_on(host, opts)

            else
              compute_puppet_msi_name(host, opts)
              install_a_puppet_msi_on(host, opts)

            end
            configure_type_defaults_on( host )
          end
        end
        alias_method :install_puppet_from_msi, :install_puppet_from_msi_on

        # @api private
        def compute_puppet_msi_name(host, opts)
          version = opts[:version]
          install_32 = host['install_32'] || opts['install_32']
          less_than_3_dot_7 = version && version_is_less(version, '3.7')

          # If there's no version declared, install the latest in the 3.x series
          if not version
            if !host.is_x86_64? || install_32
              host['dist'] = 'puppet-latest'
            else
              host['dist'] = 'puppet-x64-latest'
            end

          # Install Puppet 3.x with the x86 installer if:
          # - we are on puppet < 3.7, or
          # - we are less than puppet 4.0 and on an x86 host, or
          # - we have install_32 set on host or globally
          # Install Puppet 3.x with the x64 installer if:
          # - we are otherwise trying to install Puppet 3.x on a x64 host
          elsif less_than_3_dot_7 or not host.is_x86_64? or install_32
            host['dist'] = "puppet-#{version}"

          elsif host.is_x86_64?
             host['dist'] = "puppet-#{version}-x64"

          else
            raise "I don't understand how to install Puppet version: #{version}"
          end
        end

        # Installs Puppet Agent and dependencies from msi on provided host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :puppet_agent_version The version of Puppet Agent to install
        # @option opts [String] :win_download_url The url to download puppet from
        #
        # @note on windows, the +:ruby_arch+ host parameter can determine in addition
        # to other settings whether the 32 or 64bit install is used
        def install_puppet_agent_from_msi_on(hosts, opts)
          block_on hosts do |host|

            add_role(host, 'aio') #we are installing agent, so we want aio role
            is_config_32 = true == (host['ruby_arch'] == 'x86') || host['install_32'] || opts['install_32']
            should_install_64bit = host.is_x86_64? && !is_config_32
            arch = should_install_64bit ? 'x64' : 'x86'

            # If we don't specify a version install the latest MSI for puppet-agent
            if opts[:puppet_agent_version]
              host['dist'] = "puppet-agent-#{opts[:puppet_agent_version]}-#{arch}"
            else
              host['dist'] = "puppet-agent-#{arch}-latest"
            end

            install_a_puppet_msi_on(host, opts)
          end
        end

        # @api private
        def install_a_puppet_msi_on(hosts, opts)
          block_on hosts do |host|
            link = "#{opts[:win_download_url]}/#{host['dist']}.msi"
            if not link_exists?( link )
              raise "Puppet MSI at #{link} does not exist!"
            end


            msi_download_path = "#{host.system_temp_path}\\#{host['dist']}.msi"

            if host.is_cygwin?
              # NOTE: it is critical that -o be before -O on Windows
              on host, "curl -o \"#{msi_download_path}\" -O #{link}"

              #Because the msi installer doesn't add Puppet to the environment path
              #Add both potential paths for simplicity
              #NOTE - this is unnecessary if the host has been correctly identified as 'foss' during set up
              puppetbin_path = "\"/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin\":\"/cygdrive/c/Program Files/Puppet Labs/Puppet/bin\""
              on host, %Q{ echo 'export PATH=$PATH:#{puppetbin_path}' > /etc/bash.bashrc }
            else
              on host, powershell("$webclient = New-Object System.Net.WebClient;  $webclient.DownloadFile('#{link}','#{msi_download_path}')")
            end

            opts = { :debug => host[:pe_debug] || opts[:pe_debug] }
            install_msi_on(host, msi_download_path, {}, opts)

            configure_type_defaults_on( host )
            if not host.is_cygwin?
              host.mkdir_p host['distmoduledir']
            end
          end
        end

        # Installs Puppet and dependencies from FreeBSD ports
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install (shows warning)
        #
        # @return nil
        # @api private
        def install_puppet_from_freebsd_ports_on( hosts, opts )
          if (opts[:version])
            logger.warn "If you wish to choose a specific Puppet version, use `install_puppet_from_gem_on('~> 3.*')`"
          end

          block_on hosts do |host|
            if host['platform'] =~ /freebsd-9/
              host.install_package("puppet")
            else
              host.install_package("sysutils/puppet")
            end
          end

        end
        alias_method :install_puppet_from_freebsd_ports, :install_puppet_from_freebsd_ports_on

        # Installs Puppet and dependencies from dmg on provided host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install
        # @option opts [String] :puppet_version The version of puppet-agent to install
        # @option opts [String] :facter_version The version of Facter to install
        # @option opts [String] :hiera_version The version of Hiera to install
        # @option opts [String] :mac_download_url Url to download msi pattern of %url%/puppet-%version%.msi
        #
        # @return nil
        # @api private
        def install_puppet_from_dmg_on( hosts, opts )
          block_on hosts do |host|
            # install puppet-agent if puppet version > 4.0 OR not puppet version is provided
            if (opts[:version] && !version_is_less(opts[:version], '4.0.0')) || !opts[:version]
              if opts[:puppet_agent_version].nil?
                raise "You must specify the version of puppet-agent you " +
                      "want to install if you want to install Puppet 4.0 " +
                      "or greater on OSX"
              end

              install_puppet_agent_from_dmg_on(host, opts)

            else
              puppet_ver = opts[:version] || 'latest'
              facter_ver = opts[:facter_version] || 'latest'
              hiera_ver = opts[:hiera_version] || 'latest'

              if [puppet_ver, facter_ver, hiera_ver].include?(nil)
                raise "You need to specify versions for OSX host\n eg. install_puppet({:version => '3.6.2',:facter_version => '2.1.0',:hiera_version  => '1.3.4',})"
              end

              on host, "curl -O #{opts[:mac_download_url]}/puppet-#{puppet_ver}.dmg"
              on host, "curl -O #{opts[:mac_download_url]}/facter-#{facter_ver}.dmg"
              on host, "curl -O #{opts[:mac_download_url]}/hiera-#{hiera_ver}.dmg"

              host.install_package("puppet-#{puppet_ver}")
              host.install_package("facter-#{facter_ver}")
              host.install_package("hiera-#{hiera_ver}")

              configure_type_defaults_on( host )
            end
          end
        end
        alias_method :install_puppet_from_dmg, :install_puppet_from_dmg_on

        # Installs puppet-agent and dependencies from dmg on provided host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :puppet_agent_version The version of Puppet Agent to install, defaults to latest
        # @option opts [String] :mac_download_url Url to download msi pattern of %url%/puppet-%version%.dmg
        # @option opts [String] :puppet_collection Defaults to 'PC1'
        #
        # @return nil
        # @api private
        def install_puppet_agent_from_dmg_on(hosts, opts)
          opts[:puppet_collection] ||= 'PC1'
          opts[:puppet_collection] = opts[:puppet_collection].upcase #needs to be upcase, more lovely consistency
          block_on hosts do |host|

            add_role(host, 'aio') #we are installing agent, so we want aio role

            variant, version, arch, codename = host['platform'].to_array

            download_url = "#{opts[:mac_download_url]}/#{version}/#{opts[:puppet_collection]}/#{arch}"

            latest = get_latest_puppet_agent_build_from_url(download_url)

            agent_version = opts[:puppet_agent_version] || latest
            unless agent_version.length > 0
              raise "no puppet-agent version specified or found on at #{download_url}"
            end

            pkg_name = "puppet-agent-#{agent_version}*"
            dmg_name = "puppet-agent-#{agent_version}-1.osx#{version}.dmg"
            on host, "curl -O #{download_url}/#{dmg_name}"

            host.install_package(pkg_name)

            configure_type_defaults_on( host )
          end
        end

        # Returns the latest puppet-agent version number from a given url.
        #
        # @param [String] url         URL containing list of puppet-agent packages.
        #                             Example: https://downloads.puppetlabs.com/mac/10.11/PC1/x86_64
        #
        # @return [String] version    puppet-agent version number (e.g. 1.4.1)
        #                             Empty string if none found.
        # @api private
        def get_latest_puppet_agent_build_from_url(url)
          require 'nokogiri'
          require 'open-uri'
          page = Nokogiri::HTML(open("#{url}/?C=M;O=A"))
          agents = page.css('a').children.select{ |link| link.to_s.include? 'puppet-agent' }
          re =  /puppet-agent-(.*)-1/
          latest_match = agents[-1].to_s.match re
          if latest_match
            latest = latest_match[1]
          else
            latest = ''
          end
        end

        # Installs Puppet and dependencies from OpenBSD packages
        #
        # @param [Host, Array<Host>, String, Symbol] hosts The host to install packages on
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install (shows warning)
        #
        # @return nil
        # @api private
        def install_puppet_from_openbsd_packages_on(hosts, opts)
          if (opts[:version])
            logger.warn "If you wish to choose a specific Puppet version, use `install_puppet_from_gem_on('~> 3.*')`"
          end

          block_on hosts do |host|
            host.install_package('puppet')

            configure_type_defaults_on(host)
          end
        end

        # Installs Puppet and dependencies from gem on provided host(s)
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install, if nil installs latest
        # @option opts [String] :facter_version The version of Facter to install, if nil installs latest
        # @option opts [String] :hiera_version The version of Hiera to install, if nil installs latest
        #
        # @return nil
        # @raise [StandardError] if gem does not exist on target host
        # @api private
        def install_puppet_from_gem_on( hosts, opts )
          block_on hosts do |host|
            # There are a lot of special things to do for Solaris and Solaris 10.
            # This is easier than checking host['platform'] every time.
            is_solaris10 = host['platform'] =~ /solaris-10/
            is_solaris = host['platform'] =~ /solaris/

            # Hosts may be provisioned with csw but pkgutil won't be in the
            # PATH by default to avoid changing the behavior for Puppet's tests
            if is_solaris10
              on host, 'ln -s /opt/csw/bin/pkgutil /usr/bin/pkgutil'
            end

            # Solaris doesn't necessarily have this, but gem needs it
            if is_solaris
              on host, 'mkdir -p /var/lib'
            end

            unless host.check_for_command( 'gem' )
              gempkg = case host['platform']
                       when /solaris-11/                            then 'ruby-18'
                       when /ubuntu-14/                             then 'ruby'
                       when /solaris-10|ubuntu|debian|el-|cumulus|huaweios/  then 'rubygems'
                       when /openbsd/                               then 'ruby'
                       else
                         raise "install_puppet() called with default_action " +
                               "'gem_install' but program `gem' is " +
                               "not installed on #{host.name}"
                       end

              host.install_package gempkg
            end

            # Link 'gem' to /usr/bin instead of adding /opt/csw/bin to PATH.
            if is_solaris10
              on host, 'ln -s /opt/csw/bin/gem /usr/bin/gem'
            end

            if host['platform'] =~ /debian|ubuntu|solaris|cumulus|huaweios/
              gem_env = YAML.load( on( host, 'gem environment' ).stdout )
              gem_paths_array = gem_env['RubyGems Environment'].find {|h| h['GEM PATHS'] != nil }['GEM PATHS']
              path_with_gem = 'export PATH=' + gem_paths_array.join(':') + ':${PATH}'
              on host, "echo '#{path_with_gem}' >> ~/.bashrc"
            end

            gemflags = '--no-ri --no-rdoc --no-format-executable'

            if opts[:facter_version]
              on host, "gem install facter -v'#{opts[:facter_version]}' #{gemflags}"
            end

            if opts[:hiera_version]
              on host, "gem install hiera -v'#{opts[:hiera_version]}' #{gemflags}"
            end

            ver_cmd = opts[:version] ? "-v '#{opts[:version]}'" : ''
            on host, "gem install puppet #{ver_cmd} #{gemflags}"

            # Similar to the treatment of 'gem' above.
            # This avoids adding /opt/csw/bin to PATH.
            if is_solaris
              gem_env = YAML.load( on( host, 'gem environment' ).stdout )
              # This is the section we want - this has the dir where gem executables go.
              env_sect = 'EXECUTABLE DIRECTORY'
              # Get the directory where 'gem' installs executables.
              # On Solaris 10 this is usually /opt/csw/bin
              gem_exec_dir = gem_env['RubyGems Environment'].find {|h| h[env_sect] != nil }[env_sect]

              on host, "ln -s #{gem_exec_dir}/hiera /usr/bin/hiera"
              on host, "ln -s #{gem_exec_dir}/facter /usr/bin/facter"
              on host, "ln -s #{gem_exec_dir}/puppet /usr/bin/puppet"
            end

            # A gem install might not necessarily create these
            ['confdir', 'logdir', 'codedir'].each do |key|
              host.mkdir_p host.puppet[key] if host.puppet.has_key?(key)
            end

            configure_type_defaults_on( host )
          end
        end
        alias_method :install_puppet_from_gem,          :install_puppet_from_gem_on
        alias_method :install_puppet_agent_from_gem_on, :install_puppet_from_gem_on

        # Install official puppetlabs release repository configuration on host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        #
        # @note This method only works on redhat-like and debian-like hosts.
        #
        def install_puppetlabs_release_repo_on( hosts, repo = nil, opts = options )
          block_on hosts do |host|
            variant, version, arch, codename = host['platform'].to_array
            repo_name = repo.nil? ? '' : '-' + repo
            opts = FOSS_DEFAULT_DOWNLOAD_URLS.merge(opts)

            case variant
            when /^(fedora|el|centos|sles|cisco_nexus|cisco_ios_xr)$/
              variant_url_value = (($1 == 'centos') ? 'el' : $1)
              if variant == 'cisco_nexus'
                variant_url_value = 'cisco-wrlinux'
                version = '5'
              end
              if variant == 'cisco_ios_xr'
                variant_url_value = 'cisco-wrlinux'
                version = '7'
              end
              remote = "%s/puppetlabs-release%s-%s-%s.noarch.rpm" %
                [opts[:release_yum_repo_url], repo_name, variant_url_value, version]

              if variant == 'cisco_nexus'
                # cisco nexus requires using yum to install the repo
                host.install_package( remote )
              elsif variant == 'cisco_ios_xr'
                # cisco ios xr requires using yum to localinstall the repo
                on host, "yum -y localinstall #{remote}"
              else
                host.install_package_with_rpm( remote, '--replacepkgs',
                  { :package_proxy => opts[:package_proxy] } )
              end

            when /^(debian|ubuntu|cumulus|huaweios)$/
              deb = "puppetlabs-release%s-%s.deb" % [repo_name, codename]

              remote = URI.join( opts[:release_apt_repo_url], deb )

              on host, "wget -O /tmp/puppet.deb #{remote}"
              on host, "dpkg -i --force-all /tmp/puppet.deb"
              on host, "apt-get update"
            else
              raise "No repository installation step for #{variant} yet..."
            end
            configure_type_defaults_on( host )
          end
        end
        alias_method :install_puppetlabs_release_repo, :install_puppetlabs_release_repo_on

        # Installs the repo configs on a given host
        #
        # @param [Beaker::Host] host Host to install configs on
        # @param [String] buildserver_url URL of the buildserver
        # @param [String] package_name Name of the package
        # @param [String] build_version Version of the package
        # @param [String] copy_dir Local directory to fetch files into & SCP out of
        #
        # @return nil
        def install_repo_configs(host, buildserver_url, package_name, build_version, copy_dir)
          repo_filename = host.repo_filename( package_name, build_version )
          repo_config_folder_url = "%s/%s/%s/repo_configs/%s/" %
            [ buildserver_url, package_name, build_version, host.repo_type ]

          repo = fetch_http_file( repo_config_folder_url,
                                  repo_filename,
                                  copy_dir )

          if host[:platform] =~ /cisco_nexus/
            to_path = "#{host.package_config_dir}/#{File.basename(repo)}"
          else
            to_path = host.package_config_dir
          end
          scp_to( host, repo, to_path )

          on( host, 'apt-get update' ) if host['platform'] =~ /ubuntu-|debian-|cumulus-|huaweios-/
          nil
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
        # @param [Hash{Symbol=>String}] opts Options to alter execution.
        # @option opts [String] :dev_builds_url The URL to look for dev builds.
        # @option opts [String, Array<String>] :dev_builds_repos The repo(s)
        #                                       to check for dev builds in.
        #
        # @note puppet-agent requires :dev_builds_repos to be set to the
        #   puppet collection(s) to set the build server URL appropriately.
        #
        # @note This method only works on redhat-like and debian-like hosts.
        #
        def install_puppetlabs_dev_repo ( host, package_name, build_version,
                                  repo_configs_dir = nil,
                                  opts = options )
          variant, version, arch, codename = host['platform'].to_array
          if variant !~ /^(fedora|el|centos|debian|ubuntu|cumulus|huaweios|cisco_nexus|cisco_ios_xr|sles)$/
            raise "No repository installation step for #{variant} yet..."
          end
          repo_configs_dir ||= 'tmp/repo_configs'

          platform_configs_dir = File.join(repo_configs_dir, variant)
          opts = FOSS_DEFAULT_DOWNLOAD_URLS.merge(opts)

          # some of the uses of dev_builds_url below can't include protocol info,
          # plus this opens up possibility of switching the behavior on provided
          # url type
          _, protocol, hostname = opts[:dev_builds_url].partition /.*:\/\//
          dev_builds_url = protocol + hostname
          dev_builds_url = opts[:dev_builds_url] if variant =~ /^(fedora|el|centos)$/

          install_repo_configs( host, dev_builds_url, package_name,
                                build_version, platform_configs_dir )

          configure_type_defaults_on( host )
        end

        # Installs packages from the local development repository on the given host
        #
        # @param [Host] host An object implementing {Beaker::Hosts}'s
        #                    interface.
        # @param [Regexp] package_name The name of the package whose repository is
        #                              being installed.
        #
        # @note This method only works on redhat-like and debian-like hosts.
        # @note This method is paired to be run directly after {#install_puppetlabs_dev_repo}
        #
        def install_packages_from_local_dev_repo( host, package_name )
          if host['platform'] =~ /debian|ubuntu|cumulus|huaweios/
            find_filename = '*.deb'
            find_command  = 'dpkg -i'
          elsif host['platform'] =~ /fedora|el|centos/
            find_filename = '*.rpm'
            find_command  = 'rpm -ivh'
          else
            raise "No repository installation step for #{host['platform']} yet..."
          end
          find_command = "find /root/#{package_name} -type f -name '#{find_filename}' -exec #{find_command} {} \\;"
          on host, find_command
          configure_type_defaults_on( host )
        end

        # Install development repo of the puppet-agent on the given host(s).  Downloaded from
        # location of the form DEV_BUILDS_URL/puppet-agent/AGENT_VERSION/repos
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :puppet_agent_version The version of puppet-agent to install
        # @option opts [String] :puppet_agent_sha The sha of puppet-agent to install, defaults to provided
        #                       puppet_agent_version
        # @option opts [String] :copy_base_local Directory where puppet-agent artifact
        #                       will be stored locally
        #                       (default: 'tmp/repo_configs')
        # @option opts [String] :copy_dir_external Directory where puppet-agent
        #                       artifact will be pushed to on the external machine
        #                       (default: '/root')
        # @option opts [String] :puppet_collection Defaults to 'PC1'
        # @option opts [String] :dev_builds_url Base URL to pull artifacts from
        # @option opts [String] :copy_base_local Directory where puppet-agent artifact
        #                       will be stored locally
        #                       (default: 'tmp/repo_configs')
        # @option opts [String] :copy_dir_external Directory where puppet-agent
        #                       artifact will be pushed to on the external machine
        #                       (default: '/root')
        #
        # @note on windows, the +:ruby_arch+ host parameter can determine in addition
        # to other settings whether the 32 or 64bit install is used
        #
        # @example
        #   install_puppet_agent_dev_repo_on(host, { :puppet_agent_sha => 'd3377feaeac173aada3a2c2cedd141eb610960a7', :puppet_agent_version => '1.1.1.225.gd3377fe'  })
        #
        # @return nil
        def install_puppet_agent_dev_repo_on( hosts, opts )

          opts[:puppet_agent_version] ||= opts[:version] #backward compatability
          if not opts[:puppet_agent_version]
            raise "must provide :puppet_agent_version (puppet-agent version) for install_puppet_agent_dev_repo_on"
          end

          block_on hosts do |host|
            variant, version, arch, codename = host['platform'].to_array
            opts = FOSS_DEFAULT_DOWNLOAD_URLS.merge(opts)
            opts[:download_url] = "#{opts[:dev_builds_url]}/puppet-agent/#{ opts[:puppet_agent_sha] || opts[:puppet_agent_version] }/repos/"
            opts[:copy_base_local]    ||= File.join('tmp', 'repo_configs')
            opts[:puppet_collection] ||= 'PC1'
            add_role(host, 'aio') #we are installing agent, so we want aio role
            release_path = opts[:download_url]
            copy_dir_local = File.join(opts[:copy_base_local], variant)
            onhost_copy_base = opts[:copy_dir_external] || host.external_copy_base

            case variant
            when /^(fedora|el|centos|sles|debian|ubuntu|cumulus|huaweios|cisco_nexus|cisco_ios_xr)$/
              if arch == 's390x'
                logger.trace("#install_puppet_agent_dev_repo_on: s390x arch detected for host #{host}. using dev package")
              else
                sha = opts[:puppet_agent_sha] || opts[:puppet_agent_version]
                opts[:dev_builds_repos] ||= [ opts[:puppet_collection] ]
                install_puppetlabs_dev_repo( host, 'puppet-agent', sha, nil, opts )
                host.install_package('puppet-agent')
                logger.trace("#install_puppet_agent_dev_repo_on: install_puppetlabs_dev_repo finished")
                next
              end
            when /^(eos|osx|windows|solaris|aix)$/
              # Download installer package file & run install manually.
              # Done below, so that el hosts with s390x arch can use this
              # workflow as well
            else
              raise "No repository installation step for #{variant} yet..."
            end

            release_path_end, release_file = host.puppet_agent_dev_package_info(
              opts[:puppet_collection], opts[:puppet_agent_version], opts )
            release_path << release_path_end
            logger.trace("#install_puppet_agent_dev_repo_on: dev_package_info, continuing...")

            if variant =~ /eos/
              host.get_remote_file( "#{release_path}/#{release_file}" )
            else
              onhost_copied_file = File.join(onhost_copy_base, release_file)
              fetch_http_file( release_path, release_file, copy_dir_local)
              scp_to host, File.join(copy_dir_local, release_file), onhost_copy_base
            end

            case variant
            when /^eos/
              host.install_from_file( release_file )
            when /^(sles|aix|el)$/
              # NOTE: AIX does not support repo management. This block assumes
              # that the desired rpm has been mirrored to the 'repos' location.
              on host, "rpm -ivh #{onhost_copied_file}"
            when /^windows$/
              result = on host, "echo #{onhost_copied_file}"
              onhost_copied_file = result.raw_output.chomp
              msi_opts = { :debug => host[:pe_debug] || opts[:pe_debug] }
              install_msi_on(host, onhost_copied_file, {}, msi_opts)
            when /^osx$/
              host.install_package("puppet-agent-#{opts[:puppet_agent_version]}*")
            when /^solaris$/
              host.solaris_install_local_package( release_file, onhost_copy_base )
            end
            configure_type_defaults_on( host )
          end
        end
        alias_method :install_puppetagent_dev_repo, :install_puppet_agent_dev_repo_on

        # Install shared repo of the puppet-agent on the given host(s).  Downloaded from
        # location of the form PE_PROMOTED_BUILDS_URL/PE_VER/puppet-agent/AGENT_VERSION/repo
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :puppet_agent_version The version of puppet-agent to install, defaults to 'latest'
        # @option opts [String] :pe_ver The version of PE (will also use host['pe_ver']), defaults to '4.0'
        # @option opts [String] :copy_base_local Directory where puppet-agent artifact
        #                       will be stored locally
        #                       (default: 'tmp/repo_configs')
        # @option opts [String] :copy_dir_external Directory where puppet-agent
        #                       artifact will be pushed to on the external machine
        #                       (default: '/root')
        # @option opts [String] :puppet_collection Defaults to 'PC1'
        # @option opts [String] :pe_promoted_builds_url Base URL to pull artifacts from
        #
        # @note on windows, the +:ruby_arch+ host parameter can determine in addition
        # to other settings whether the 32 or 64bit install is used
        #
        # @example
        #   install_puppet_agent_pe_promoted_repo_on(host, { :puppet_agent_version => '1.1.0.227', :pe_ver => '4.0.0-rc1'})
        #
        # @return nil
        def install_puppet_agent_pe_promoted_repo_on( hosts, opts )
          opts[:puppet_agent_version] ||= 'latest'

          block_on hosts do |host|
            pe_ver = host[:pe_ver] || opts[:pe_ver] || '4.0.0-rc1'
            opts = FOSS_DEFAULT_DOWNLOAD_URLS.merge(opts)
            opts[:download_url] = "#{opts[:pe_promoted_builds_url]}/puppet-agent/#{ pe_ver }/#{ opts[:puppet_agent_version] }/repos"
            opts[:copy_base_local]    ||= File.join('tmp', 'repo_configs')
            opts[:copy_dir_external]  ||= host.external_copy_base
            opts[:puppet_collection] ||= 'PC1'
            add_role(host, 'aio') #we are installing agent, so we want aio role
            release_path = opts[:download_url]
            variant, version, arch, codename = host['platform'].to_array
            copy_dir_local = File.join(opts[:copy_base_local], variant)
            onhost_copy_base = opts[:copy_dir_external]

            release_path_end, release_file, download_file =
              host.pe_puppet_agent_promoted_package_info(
                opts[:puppet_collection], opts
              )
            release_path << release_path_end

            onhost_copied_download = File.join(onhost_copy_base, download_file)
            onhost_copied_file = File.join(onhost_copy_base, release_file)
            fetch_http_file( release_path, download_file, copy_dir_local)
            scp_to host, File.join(copy_dir_local, download_file), onhost_copy_base

            if variant == 'windows'
              result = on host, "echo #{onhost_copied_file}"
              onhost_copied_file = result.raw_output.chomp
              opts = { :debug => host[:pe_debug] || opts[:pe_debug] }
              # couldn't pull this out, because it's relying on
              # {Beaker::DSL::InstallUtils::WindowsUtils} methods,
              # which I didn't want to attack right now. TODO
              install_msi_on(host, onhost_copied_file, {}, opts)
            else
              host.pe_puppet_agent_promoted_package_install(
                onhost_copy_base, onhost_copied_download,
                onhost_copied_file, download_file, opts
              )
            end
            configure_type_defaults_on( host )
          end
        end

        # This method will install a pem file certificate on a windows host
        #
        # @param [Host] host                 A host object
        # @param [String] cert_name          The name of the pem file
        # @param [String] cert               The contents of the certificate
        #
        def install_cert_on_windows(host, cert_name, cert)
          create_remote_file(host, "C:\\Windows\\Temp\\#{cert_name}.pem", cert)
          on host, "certutil -v -addstore Root C:\\Windows\\Temp\\#{cert_name}.pem"
        end

        # Ensures Puppet and dependencies are no longer installed on host(s).
        #
        # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
        #                            or a role (String or Symbol) that identifies one or more hosts.
        #
        # @return nil
        # @api public
        def remove_puppet_on( hosts )
          block_on hosts do |host|
            cmdline_args = ''
            # query packages
            case host[:platform]
            when /cumulus|huaweios/
              pkgs = on(host, "dpkg-query -l  | awk '{print $2}' | grep -E '(^pe-|puppet)'", :acceptable_exit_codes => [0,1]).stdout.chomp.split(/\n+/)
            when /aix|sles|el|redhat|centos|oracle|scientific/
              pkgs = on(host, "rpm -qa  | grep -E '(^pe-|puppet)'", :acceptable_exit_codes => [0,1]).stdout.chomp.split(/\n+/)
            when /solaris-10/
              cmdline_args = '-a noask'
              pkgs = on(host, "pkginfo | egrep '(^pe-|puppet)' | cut -f2 -d ' '", :acceptable_exit_codes => [0,1]).stdout.chomp.split(/\n+/)
            when /solaris-11/
              pkgs = on(host, "pkg list | egrep '(^pe-|puppet)' | awk '{print $1}'", :acceptable_exit_codes => [0,1]).stdout.chomp.split(/\n+/)
            else
              raise "remove_puppet_on() called for unsupported " +
                    "platform '#{host['platform']}' on '#{host.name}'"
            end

            # uninstall packages
            host.uninstall_package(pkgs.join(' '), cmdline_args) if pkgs.length > 0

            if host[:platform] =~ /solaris-11/ then
              # FIXME: This leaves things in a state where Puppet Enterprise (3.x) cannot be cleanly installed
              #        but is required to put things in a state that puppet-agent can be installed
              # extra magic for expunging left over publisher
              publishers = ['puppetlabs.com', 'com.puppetlabs']
              publishers.each do |publisher|
                if on(host, "pkg publisher #{publisher}", :acceptable_exit_codes => [0,1]).exit_code == 0 then
                  # First, try to remove the publisher altogether
                  if on(host, "pkg unset-publisher #{publisher}", :acceptable_exit_codes => [0,1]).exit_code == 1 then
                    # If that doesn't work, we're in a non-global zone and the
                    # publisher is from a global zone. As such, just remove any
                    # references to the non-global zone uri.
                    on(host, "pkg set-publisher -G '*' #{publisher}", :acceptable_exit_codes => [0,1])
                  end
                end
              end
            end

            # delete any residual files
            on(host, 'find / -name "*puppet*" -print | xargs rm -rf')

          end
        end
      end
    end
  end
end
