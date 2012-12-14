require 'pathname'

module PuppetAcceptance
  module DSL
    module InstallUtils

      SourcePath  = "/opt/puppet-git-repos"
      GitURI       = %r{^(git|https?)://|^git@}
      GitHubSig   = 'github.com,207.97.227.239 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=='

      def extract_repo_info_from uri
        project = {}
        repo, rev = uri.split('#', 2)
        project[:name] = Pathname.new(repo).basename('.git').to_s
        project[:path] = repo
        project[:rev]  = rev || 'HEAD'
        return project
      end

      # crude, viscious sorting...
      def order_packages packages_array
        puppet = packages_array.select {|e| e[:name] == 'puppet' }
        puppet_depends = packages_array.select {|e| e[:name] == 'hiera' or e[:name] == 'facter' }
        depends_puppet = packages_array - puppet
        depends_puppet = packages_array - puppet_depends
        [puppet_depends, puppet, depends_puppet].flatten
      end

      def find_git_repo_versions host, path, repository
        step "Grab version for #{repository[:name]}"
        version = {}
        on host, "cd #{path}/#{repository[:name]} && " +
                  "git describe || true" do |tc|
          version[repository[:name]] = tc.result.stdout.chomp
        end
        version
      end

      def install_from_git host, path, repository
        name   = repository[:name]
        repo   = repository[:path]
        rev    = repository[:rev]
        target = "#{path}/#{name}"

        step "Clone #{repo} if needed"
        on host, "test -d #{path} || mkdir -p #{path}"
        on host, "test -d #{target} || git clone #{repo} #{target}"

        step "Update #{name} and check out revision #{rev}"
        commands = ["cd #{target}",
                    "remote rm origin",
                    "remote add origin #{repo}",
                    "fetch origin",
                    "clean -fdx",
                    "checkout -f #{rev}"]
        on host, commands.join(" && git ")

        step "Install #{name} on the system"
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
