module Unix::Pkg
  include Beaker::CommandFactory

  # This method overrides {Beaker::Host#pkg_initialize} to provide
  # unix-specific package management setup
  def pkg_initialize
    @apt_needs_update = true
  end

  def check_for_command(name)
    result = exec(Beaker::Command.new("which #{name}"), :accept_all_exit_codes => true)
    case self['platform']
    when /solaris-10/
      result.stdout =~ %r|/.*/#{name}|
    else
      result.exit_code == 0
    end
  end

  def check_for_package(name, opts = {})
    opts = {:accept_all_exit_codes => true}.merge(opts)
    case self['platform']
      when /sles-10/
        result = execute("zypper se -i --match-exact #{name}", opts) { |result| result }
        result.stdout =~ /No packages found/ ? (return false) : (return result.exit_code == 0)
      when /sles-/
        result = execute("zypper se -i --match-exact #{name}", opts) { |result| result }
      when /el-4/
        @logger.debug("Package query not supported on rhel4")
        return false
      when /cisco|fedora|centos|eos|el-/
        result = execute("rpm -q #{name}", opts) { |result| result }
      when /ubuntu|debian|cumulus/
        result = execute("dpkg -s #{name}", opts) { |result| result }
      when /solaris-11/
        result = execute("pkg info #{name}", opts) { |result| result }
      when /solaris-10/
        result = execute("pkginfo #{name}", opts) { |result| result }
      when /freebsd-9/
        result = execute("pkg_info #{name}", opts) { |result| result }
      when /freebsd-10/
        result = execute("pkg info #{name}", opts) { |result| result }
      when /openbsd/
        result = execute("pkg_info #{name}", opts) { |result| result }
      else
        raise "Package #{name} cannot be queried on #{self}"
    end
    result.exit_code == 0
  end

  # If apt has not been updated since the last repo deployment it is
  # updated. Otherwise this is a noop
  def update_apt_if_needed
    if self['platform'] =~ /debian|ubuntu|cumulus/
      if @apt_needs_update
        execute("apt-get update")
        @apt_needs_update = false
      end
    end
  end

  def install_package(name, cmdline_args = '', version = nil, opts = {})
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive in #{name}", opts)
      when /el-4/
        @logger.debug("Package installation not supported on rhel4")
      when /fedora-22/
        if version
          name = "#{name}-#{version}"
        end
        execute("dnf -y #{cmdline_args} install #{name}", opts)
      when /cisco|fedora|centos|eos|el-/
        if version
          name = "#{name}-#{version}"
        end
        execute("yum -y #{cmdline_args} install #{name}", opts)
      when /ubuntu|debian|cumulus/
        if version
          name = "#{name}=#{version}"
        end
        update_apt_if_needed
        execute("apt-get install --force-yes #{cmdline_args} -y #{name}", opts)
      when /solaris-11/
        execute("pkg #{cmdline_args} install #{name}", opts)
      when /solaris-10/
        execute("pkgutil -i -y #{cmdline_args} #{name}", opts)
      when /freebsd-9/
        execute("pkg_add -fr #{cmdline_args} #{name}", opts)
      when /freebsd-10/
        execute("pkg #{cmdline_args} install #{name}", opts)
      when /openbsd/
        begin
          execute("pkg_add -I #{cmdline_args} #{name}", opts) do |command|
            # Handles where there are multiple rubies, installs the latest one
            if command.stderr =~ /^Ambiguous: #{name} could be (.+)$/
              name = $1.chomp.split(' ').collect { |x|
                x =~ /-(\d[^-p]+)/
                [x, $1]
              }.select { |x|
                # Blacklist Ruby 2.2.0+ for the sake of Puppet 3.x
                Gem::Version.new(x[1]) < Gem::Version.new('2.2.0')
              }.sort { |a,b|
                Gem::Version.new(b[1]) <=> Gem::Version.new(a[1])
              }.collect { |x|
                x[0]
              }.first
              raise ArgumentException
            end
            # If the package advises symlinks to be created, do it
            command.stdout.split(/\n/).select { |x| x =~ /^\s+ln\s/ }.each do |ln|
              execute(ln, opts)
            end
          end
        rescue
          retry
        end
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  def uninstall_package(name, cmdline_args = '', opts = {})
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive rm #{name}", opts)
      when /el-4/
        @logger.debug("Package uninstallation not supported on rhel4")
      when /fedora-22/
        execute("dnf -y #{cmdline_args} remove #{name}", opts)
      when /cisco|fedora|centos|eos|el-/
        execute("yum -y #{cmdline_args} remove #{name}", opts)
      when /ubuntu|debian|cumulus/
        execute("apt-get purge #{cmdline_args} -y #{name}", opts)
      when /solaris-11/
        execute("pkg #{cmdline_args} uninstall #{name}", opts)
      when /solaris-10/
        execute("pkgrm -n #{cmdline_args} #{name}", opts)
      when /aix/
        execute("rpm #{cmdline_args} -e #{name}", opts)
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  # Upgrade an installed package to the latest available version
  #
  # @param [String] name          The name of the package to update
  # @param [String] cmdline_args  Additional command line arguments for
  #                               the package manager
  def upgrade_package(name, cmdline_args = '', opts = {})
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive --no-gpg-checks up #{name}", opts)
      when /el-4/
        @logger.debug("Package upgrade is not supported on rhel4")
      when /fedora-22/
        execute("dnf -y #{cmdline_args} update #{name}", opts)
      when /cisco|fedora|centos|eos|el-/
        execute("yum -y #{cmdline_args} update #{name}", opts)
      when /ubuntu|debian|cumulus/
        update_apt_if_needed
        execute("apt-get install -o Dpkg::Options::='--force-confold' #{cmdline_args} -y --force-yes #{name}", opts)
      when /solaris-11/
        execute("pkg #{cmdline_args} update #{name}", opts)
      when /solaris-10/
        execute("pkgutil -u -y #{cmdline_args} ${name}", opts)
      else
        raise "Package #{name} cannot be upgraded on #{self}"
    end
  end

  # Deploy apt configuration generated by the packaging tooling
  #
  # @note Due to the debian use of codenames in repos, the
  #       DEBIAN_PLATFORM_CODENAMES map must be kept up-to-date as
  #       support for new versions is added.
  #
  # @note See {Beaker::DSL::Helpers::HostHelpers#deploy_package_repo} for info on
  #       params
  def deploy_apt_repo(path, name, version)
    codename = self['platform'].codename

    if codename.nil?
      @logger.warning "Could not determine codename for debian platform #{self['platform']}. Skipping deployment of repo #{name}"
      return
    end

    repo_file = "#{path}/deb/pl-#{name}-#{version}-#{codename}.list"
    do_scp_to repo_file, "/etc/apt/sources.list.d/#{name}.list", {}
    @apt_needs_update = true
  end

  # Deploy yum configuration generated by the packaging tooling
  #
  # @note See {Beaker::DSL::Helpers::HostHelpers#deploy_package_repo} for info on
  #       params
  def deploy_yum_repo(path, name, version)
    repo_file = "#{path}/rpm/pl-#{name}-#{version}-repos-pe-#{self['platform']}.repo"
    do_scp_to repo_file, "/etc/yum.repos.d/#{name}.repo", {}
  end

  # Deploy zypper repo configuration generated by the packaging tooling
  #
  # @note See {Beaker::DSL::Helpers::HostHelpers#deploy_package_repo} for info on
  #       params
  def deploy_zyp_repo(path, name, version)
    repo_file = "#{path}/rpm/pl-#{name}-#{version}-repos-pe-#{self['platform']}.repo"
    repo = IniFile.load(repo_file)
    repo_name = repo.sections[0]
    repo_url = repo[repo_name]["baseurl"]
    execute("zypper ar -t YUM #{repo_url} #{repo_name}")
  end

  # Deploy configuration generated by the packaging tooling to this host.
  #
  # This method calls one of #deploy_apt_repo, #deploy_yum_repo, or
  # #deploy_zyp_repo depending on the platform of this Host.
  #
  # @note See {Beaker::DSL::Helpers::HostHelpers#deploy_package_repo} for info on
  #       params
  def deploy_package_repo(path, name, version)
    if not File.exists? path
      @logger.warning "Was asked to deploy package repository from #{path}, but it doesn't exist!"
      return
    end

    case self['platform']
      when /el-4/
        @logger.debug("Package repo deploy is not supported on rhel4")
      when /fedora|centos|eos|el-/
        deploy_yum_repo(path, name, version)
      when /ubuntu|debian|cumulus/
        deploy_apt_repo(path, name, version)
      when /sles/
        deploy_zyp_repo(path, name, version)
      else
        # solaris, windows
        raise "Package repo cannot be deployed on #{self}; the platform is not supported"
    end
  end

  #Examine the host system to determine the architecture
  #@return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    if self[:platform] =~ /solaris/
      result = exec(Beaker::Command.new("uname -a | grep x86_64"), :accept_all_exit_codes => true)
        result.exit_code == 0
    else
      result = exec(Beaker::Command.new("arch | grep x86_64"), :accept_all_exit_codes => true)
      result.exit_code == 0
    end
  end

end
