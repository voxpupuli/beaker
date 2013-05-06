require 'pathname'

module PuppetAcceptance
  module DSL
    #
    # This module contains methods to help cloning, extracting git info,
    # ordering of Puppet packages, and installing ruby projects that
    # contain an `install.rb` script.
    module InstallUtils

      # The default install path
      SourcePath  = "/opt/puppet-git-repos"

      # A regex to know if the uri passed is pointing to a git repo
      GitURI       = %r{^(git|https?|file)://|^git@}

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

      # @param [Host] host An object implementing {PuppetAcceptance::Hosts}'s
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
      #       * {PuppetAcceptance::DSL::Structure#step}
      #       * {PuppetAcceptance::DSL::Helpers#on}
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
    end
  end
end
