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
      module PuppetUtils

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
        #       * {Beaker::DSL::Structure#step}
        #       * {Beaker::DSL::Helpers#on}
        #
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

          step "Clone #{repo} if needed" do
            on host, "test -d #{path} || mkdir -p #{path}"
            on host, "test -d #{target} || #{clone_cmd}"
          end

          step "Update #{name} and check out revision #{rev}" do
            commands = ["cd #{target}",
                        "remote rm origin",
                        "remote add origin #{repo}",
                        "fetch origin +refs/pull/*:refs/remotes/origin/pr/* +refs/heads/*:refs/remotes/origin/*",
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
        #       Debian, Ubuntu, or Cumulus machines, or yum.puppetlabs.com on EL or Fedora
        #       machines, then install the package 'puppet'.
        # @param [Hash{Symbol=>String}] opts
        # @option opts [String] :version Version of puppet to download
        # @option opts [String] :mac_download_url Url to download msi pattern of %url%/puppet-%version%.msi
        # @option opts [String] :win_download_url Url to download dmg  pattern of %url%/(puppet|hiera|facter)-%version%.msi
        #
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
            elsif host['platform'] =~ /(ubuntu|debian|cumulus)/
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
            on host, "mkdir -p #{host['puppetpath']}" unless host[:type] =~ /aio/
            on host, "echo '' >> #{host.puppet['hiera_config']}"
          end
          nil
        end

        # Configure puppet.conf for all hosts based upon a provided Hash
        # @param [Hash{Symbol=>String}] opts
        # @option opts [Hash{String=>String}] :main configure the main section of puppet.conf
        # @option opts [Hash{String=>String}] :agent configure the agent section of puppet.conf
        #
        # @return nil
        def configure_puppet(opts={})
          hosts.each do |host|
            configure_puppet_on(host,opts)
          end
        end

        # Configure puppet.conf on the given host based upon a provided hash
        # @param [Host] host The host to configure puppet.conf on
        # @param [Hash{Symbol=>String}] opts
        # @option opts [Hash{String=>String}] :main configure the main section of puppet.conf
        # @option opts [Hash{String=>String}] :agent configure the agent section of puppet.conf
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
        #   configure_puppet(master, config)
        #
        # @return nil
        def configure_puppet_on(host, opts = {})
          if host['platform'] =~ /windows/
            puppet_conf = host.puppet['config']
            conf_data = ''
            opts.each do |section,options|
              conf_data << "[#{section}]`n"
              options.each do |option,value|
                conf_data << "#{option}=#{value}`n"
              end
              conf_data << "`n"
            end
            on host, powershell("\$text = \\\"#{conf_data}\\\"; Set-Content -path '#{puppet_conf}' -value \$text")
          else
            puppet_conf = host.puppet['config']
            conf_data = ''
            opts.each do |section,options|
              conf_data << "[#{section}]\n"
              options.each do |option,value|
                conf_data << "#{option}=#{value}\n"
              end
              conf_data << "\n"
            end
            on host, "echo \"#{conf_data}\" > #{puppet_conf}"
          end
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

          on host, "rpm -q --quiet puppetlabs-release || rpm -ivh #{release_package_string}"

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
        # @note on windows, the +:ruby_arch+ host parameter can determine in addition
        # to other settings whether the 32 or 64bit install is used
        def install_puppet_from_msi( host, opts )
          #only install 64bit builds if
          # - we are on puppet version 3.7+
          # - we do not have install_32 set on host
          # - we do not have install_32 set globally
          version = opts[:version]
          is_config_32 = host['ruby_arch'] == 'x86' || host['install_32'] || opts['install_32']
          if !(version_is_less(version, '3.7')) && host.is_x86_64? && !is_config_32
            host['dist'] = "puppet-#{version}-x64"
          else
            host['dist'] = "puppet-#{version}"
          end
          link = "#{opts[:win_download_url]}/#{host['dist']}.msi"
          if not link_exists?( link )
            raise "Puppet #{version} at #{link} does not exist!"
          end

          if host.is_cygwin?
            dest = "#{host['dist']}.msi"
            on host, "curl -O #{link}"

            #Because the msi installer doesn't add Puppet to the environment path
            #Add both potential paths for simplicity
            #NOTE - this is unnecessary if the host has been correctly identified as 'foss' during set up
            puppetbin_path = "\"/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin\":\"/cygdrive/c/Program Files/Puppet Labs/Puppet/bin\""
            on host, %Q{ echo 'export PATH=$PATH:#{puppetbin_path}' > /etc/bash.bashrc }
          else
            dest = "C:\\Windows\\Temp\\#{host['dist']}.msi"

            on host, powershell("$webclient = New-Object System.Net.WebClient;  $webclient.DownloadFile('#{link}','#{dest}')")

            host.mkdir_p host['distmoduledir']
          end

          if host.is_cygwin?
            on host, "cmd /C 'start /w msiexec.exe /qn /i #{dest}'"
          else
            on host, "start /w msiexec.exe /qn /i #{dest}"
          end
        end

        # Installs Puppet and dependencies from dmg
        #
        # @param [Host] host The host to install packages on
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of Puppet to install, required
        # @option opts [String] :facter_version The version of Facter to install, required
        # @option opts [String] :hiera_version The version of Hiera to install, required
        # @option opts [String] :mac_download_url Url to download msi pattern of %url%/puppet-%version%.msi
        #
        # @return nil
        # @api private
        def install_puppet_from_dmg( host, opts )

          puppet_ver = opts[:version]
          facter_ver = opts[:facter_version]
          hiera_ver = opts[:hiera_version]

          if [puppet_ver, facter_ver, hiera_ver].include?(nil)
            raise "You need to specify versions for OSX host\n eg. install_puppet({:version => '3.6.2',:facter_version => '2.1.0',:hiera_version  => '1.3.4',})"
          end

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
                     when /solaris-10|ubuntu|debian|el-|cumulus/  then 'rubygems'
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

          if host['platform'] =~ /debian|ubuntu|solaris|cumulus/
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

            on host, "rpm -ivh #{rpm}"

          when /^(debian|ubuntu|cumulus)$/
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
        # @param [Hash{Symbol=>String}] opts Options to alter execution.
        # @option opts [String] :dev_builds_url The URL to look for dev builds.
        # @option opts [String, Array<String>] :dev_builds_repos The repo(s)
        #                                       to check for dev builds in.
        #
        # @note This method only works on redhat-like and debian-like hosts.
        #
        def install_puppetlabs_dev_repo ( host, package_name, build_version,
                                  repo_configs_dir = 'tmp/repo_configs',
                                  opts = options )
          variant, version, arch, codename = host['platform'].to_array
          platform_configs_dir = File.join(repo_configs_dir, variant)

          # some of the uses of dev_builds_url below can't include protocol info,
          # plus this opens up possibility of switching the behavior on provided
          # url type
          _, protocol, hostname = opts[:dev_builds_url].partition /.*:\/\//
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

            link = nil
            package_repos = opts[:dev_builds_repos].nil? ? [] : [opts[:dev_builds_repos]]
            package_repos.push(['products', 'devel']).flatten!
            package_repos.each do |repo|
              link =  "%s/%s/%s/repos/%s/%s%s/%s/%s/" %
                [ dev_builds_url, package_name, build_version, variant,
                  fedora_prefix, version, repo, arch ]

              unless link_exists?( link )
                logger.debug("couldn't find link at '#{repo}', falling back to next option...")
              else
                logger.debug("found link at '#{repo}'")
                break
              end
            end
            raise "Unable to reach a repo directory at #{link}" unless link_exists?( link )

            repo_dir = fetch_http_dir( link, platform_configs_dir )

            config_dir = '/etc/yum.repos.d/'
            scp_to host, repo, config_dir
            scp_to host, repo_dir, "/root/#{package_name}"

            search = "baseurl\\s*=\\s*http:\\/\\/#{hostname}.*$"
            replace = "baseurl=file:\\/\\/\\/root\\/#{package_name}\\/#{arch}"
            sed_command = "sed -i 's/#{search}/#{replace}/'"
            find_and_sed = "find #{config_dir} -name \"*.repo\" -exec #{sed_command} {} \\;"

            on host, find_and_sed

          when /^(debian|ubuntu|cumulus)$/
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

            repo_name = nil
            package_repos = opts[:dev_builds_repos].nil? ? [] : [opts[:dev_builds_repos]]
            package_repos.flatten!
            package_repos.each do |repo|
              repo_path = "/root/#{package_name}/#{codename}/#{repo}"
              repo_check = on(host, "[[ -d #{repo_path} ]]", :acceptable_exit_codes => [0,1])
              if repo_check.exit_code == 0
                logger.debug("found repo at '#{repo_path}'")
                repo_name = repo
                break
              else
                logger.debug("couldn't find repo at '#{repo_path}', falling back to next option...")
              end
            end
            if repo_name.nil?
              repo_name = 'main'
              logger.debug("using default repo '#{repo_name}'")
            end

            search = "deb\\s\\+http:\\/\\/#{hostname}.*$"
            replace = "deb file:\\/\\/\\/root\\/#{package_name}\\/#{codename} #{codename} #{repo_name}"
            sed_command = "sed -i 's/#{search}/#{replace}/'"
            find_and_sed = "find #{config_dir} -name \"*.list\" -exec #{sed_command} {} \\;"

            on host, find_and_sed
            on host, "apt-get update"

          else
            raise "No repository installation step for #{variant} yet..."
          end
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
          if host['platform'] =~ /debian|ubuntu|cumulus/
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
        end

        # Install development repo of the puppet-agent on the given host
        #
        # @param [Host] host An object implementing {Beaker::Hosts}'s interface
        # @param [Hash{Symbol=>String}] opts An options hash
        # @option opts [String] :version The version of puppet-agent to install
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
        # @return nil
        def install_puppetagent_dev_repo( host, opts )
          opts[:copy_base_local]    ||= File.join('tmp', 'repo_configs')
          opts[:copy_dir_external]  ||= File.join('/', 'root')
          variant, version, arch, codename = host['platform'].to_array
          release_path = "#{options[:dev_builds_url]}/puppet-agent/#{opts[:version]}/artifacts/"
          copy_dir_local = File.join(opts[:copy_base_local], variant)
          onhost_copy_base = opts[:copy_dir_external]

          case variant
          when /^(fedora|el|centos)$/
            release_path << "el/#{version}/products/#{arch}"
            release_file = "puppet-agent-#{opts[:version]}-1.#{arch}.rpm"
          when /^(debian|ubuntu|cumulus)$/
            release_path << "deb/#{codename}"
            release_file = "puppet-agent_#{opts[:version]}-1_#{arch}.deb"
          when /^windows$/
            release_path << 'windows'
            onhost_copy_base = '`cygpath -smF 35`/'
            is_config_32 = host['ruby_arch'] == 'x86' || host['install_32'] || opts['install_32']
            should_install_64bit = host.is_x86_64? && !is_config_32
            # only install 64bit builds if
            # - we do not have install_32 set on host
            # - we do not have install_32 set globally
            arch_suffix = should_install_64bit ? '64' : '86'
            release_file = "puppet-agent-x#{arch_suffix}.msi"
          else
            raise "No repository installation step for #{variant} yet..."
          end

          onhost_copied_file = File.join(onhost_copy_base, release_file)
          fetch_http_file( release_path, release_file, copy_dir_local)
          scp_to host, File.join(copy_dir_local, release_file), onhost_copy_base

          case variant
          when /^(fedora|el|centos)$/
            on host, "rpm -ivh #{onhost_copied_file}"
          when /^(debian|ubuntu|cumulus)$/
            on host, "dpkg -i --force-all #{onhost_copied_file}"
            on host, "apt-get update"
          when /^windows$/
            result = on host, "echo #{onhost_copied_file}"
            onhost_copied_file = result.raw_output.chomp
            on host, Command.new("start /w #{onhost_copied_file}", [], { :cmdexe => true })
          end
        end

        # This method will install a pem file certifcate on a windows host
        #
        # @param [Host] host                 A host object
        # @param [String] cert_name          The name of the pem file
        # @param [String] cert               The contents of the certificate
        #
        def install_cert_on_windows(host, cert_name, cert)
          create_remote_file(host, "C:\\Windows\\Temp\\#{cert_name}.pem", cert)
          on host, "certutil -v -addstore Root C:\\Windows\\Temp\\#{cert_name}.pem"
        end
      end
    end
  end
end
