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
    opts[:prepend_cmds] ? pc = "#{opts[:prepend_cmds]} " : pc = ""
    case self['platform']
      when /sles-10/
        result = exec(Beaker::Command.new("#{pc}zypper se -i --match-exact #{name}"), opts)
        result.stdout =~ /No packages found/ ? (return false) : (return result.exit_code == 0)
      when /sles-/
        result = exec(Beaker::Command.new("#{pc}zypper se -i --match-exact #{name}"), opts)
      when /el-4/
        @logger.debug("Package query not supported on rhel4")
        return false
      when /cisco|fedora|centos|eos|el-/
        result = exec(Beaker::Command.new("#{pc}rpm -q #{name}"), opts)
      when /ubuntu|debian|cumulus/
        result = exec(Beaker::Command.new("#{pc}dpkg -s #{name}"), opts)
      when /solaris-11/
        result = exec(Beaker::Command.new("#{pc}pkg info #{name}"), opts)
      when /solaris-10/
        result = exec(Beaker::Command.new("#{pc}pkginfo #{name}"), opts)
      when /freebsd-9/
        result = exec(Beaker::Command.new("#{pc}pkg_info #{name}"), opts)
      when /freebsd-10/
        result = exec(Beaker::Command.new("#{pc}pkg info #{name}"), opts)
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
    opts[:prepend_cmds] ? pc = "#{opts[:prepend_cmds]} " : pc = ""
    case self['platform']
      when /sles-/
        execute("#{pc}zypper --non-interactive in #{name}", opts)
      when /el-4/
        @logger.debug("Package installation not supported on rhel4")
      when /cisco|fedora|centos|eos|el-/
        if version
          name = "#{name}-#{version}"
        end
        execute("#{pc}yum -y #{cmdline_args} install #{name}", opts)
      when /ubuntu|debian|cumulus/
        if version
          name = "#{name}=#{version}"
        end
        update_apt_if_needed
        execute("#{pc}apt-get install --force-yes #{cmdline_args} -y #{name}", opts)
      when /solaris-11/
        execute("#{pc}pkg #{cmdline_args} install #{name}", opts)
      when /solaris-10/
        execute("#{pc}pkgutil -i -y #{cmdline_args} #{name}", opts)
      when /freebsd-9/
        execute("#{pc}pkg_add -fr #{cmdline_args} #{name}", opts)
      when /freebsd-10/
        execute("#{pc}pkg #{cmdline_args} install #{name}", opts)
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  def uninstall_package(name, cmdline_args = '', opts = {})
    opts[:prepend_cmds] ? pc = "#{opts[:prepend_cmds]} " : pc = ""
    case self['platform']
      when /sles-/
        execute("#{pc}zypper --non-interactive rm #{name}", opts)
      when /el-4/
        @logger.debug("Package uninstallation not supported on rhel4")
      when /cisco|fedora|centos|eos|el-/
        execute("#{pc}yum -y #{cmdline_args} remove #{name}", opts)
      when /ubuntu|debian|cumulus/
        execute("#{pc}apt-get purge #{cmdline_args} -y #{name}", opts)
      when /solaris-11/
        execute("#{pc}pkg #{cmdline_args} uninstall #{name}", opts)
      when /solaris-10/
        execute("#{pc}pkgutil -r -y #{cmdline_args} #{name}", opts)
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
    opts[:prepend_cmds] ? pc = "#{opts[:prepend_cmds]} " : pc = ""
    case self['platform']
      when /sles-/
        execute("#{pc}zypper --non-interactive --no-gpg-checks up #{name}", opts)
      when /el-4/
        @logger.debug("Package upgrade is not supported on rhel4")
      when /cisco|fedora|centos|eos|el-/
        execute("#{pc}yum -y #{cmdline_args} update #{name}", opts)
      when /ubuntu|debian|cumulus/
        update_apt_if_needed
        execute("#{pc}apt-get install -o Dpkg::Options::='--force-confold' #{cmdline_args} -y --force-yes #{name}", opts)
      when /solaris-11/
        execute("#{pc}pkg #{cmdline_args} update #{name}", opts)
      when /solaris-10/
        execute("#{pc}pkgutil -u -y #{cmdline_args} ${name}", opts)
      else
        raise "Package #{name} cannot be upgraded on #{self}"
    end
  end

  # Debian repositories contain packages for all architectures, so we
  # need to map to an architecturless name for each platform
  DEBIAN_PLATFORM_CODENAMES = {
    'debian-6-amd64'     => 'squeeze',
    'debian-6-i386'      => 'squeeze',
    'debian-7-amd64'     => 'wheezy',
    'debian-7-i386'      => 'wheezy',
    'ubuntu-10.04-amd64' => 'lucid',
    'ubuntu-10.04-i386'  => 'lucid',
    'ubuntu-12.04-amd64' => 'precise',
    'ubuntu-12.04-i386'  => 'precise',
  }

  # Deploy apt configuration generated by the packaging tooling
  #
  # @note Due to the debian use of codenames in repos, the
  #       DEBIAN_PLATFORM_CODENAMES map must be kept up-to-date as
  #       support for new versions is added.
  #
  # @note See {Beaker::DSL::Helpers::HostHelpers#deploy_package_repo} for info on
  #       params
  def deploy_apt_repo(path, name, version)
    codename = DEBIAN_PLATFORM_CODENAMES[self['platform']]
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
