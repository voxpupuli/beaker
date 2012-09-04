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
        on host, "cd #{target} && if [ -f install.rb ]; then ruby ./install.rb --bindir=/usr/bin --sbindir=/usr/sbin; else true; fi"
      end
    end
  end
end
