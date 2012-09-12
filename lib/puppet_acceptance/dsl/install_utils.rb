module PuppetAcceptance
  module DSL
    module InstallUtils

      SourcePath  = "/opt/puppet-git-repos"

      def install_from_git(host, package, repo, revision)
        target = "#{SourcePath}/#{package}"

        step "Clone #{repo} if needed"
        on host, "test -d #{SourcePath} || mkdir -p #{SourcePath}"
        on host, "test -d #{target} || git clone #{repo} #{target}"

        step "Update #{package} and check out revision #{revision}"
        commands = ["cd #{target}",
                    "remote rm origin",
                    "remote add origin #{repo}",
                    "fetch origin",
                    "clean -fdx",
                    "checkout -f #{revision}"]
        on host, commands.join(" && git ")

        step "Install #{package} on the system"
        # The solaris ruby package runtime/ruby-18@1.8.7.334,5.11-0.175.0.0.0.2.537:20111019T113301Z
        # has bindir set to /usr/ruby/1.8/bin. However, this is not the path to
        # which we want to deliver our binaries. So if we are using solaris, we
        # have to pass the bin and sbin directories to the install.rb rather
        # than use the compiled in ruby bin and sbin directories
        if host['platform'].include? 'solaris'
          on host, "cd #{target} && if [ -f install.rb ]; then ruby ./install.rb --bindir=/usr/bin --sbindir=/usr/sbin; else true; fi"
        else
          on host, "cd #{target} && if [ -f install.rb ]; then ruby ./install.rb; else true; fi"
        end
      end
    end
  end
end
