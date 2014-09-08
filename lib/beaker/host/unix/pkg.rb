module Unix::Pkg
  include Beaker::CommandFactory

  # This method overrides {Beaker::Host#pkg_initialize} to provide
  # unix-specific package management setup
  def pkg_initialize
    @apt_needs_update = true
    @emerge_needs_sync = true
  end

  def check_for_command(name)
    result = exec(Beaker::Command.new("which #{name}"), :acceptable_exit_codes => (0...127))
    case self['platform']
    when /solaris-10/
      result.stdout =~ %r|/.*/#{name}|
    else
      result.exit_code == 0
    end
  end

  def check_for_package(name)
    case self['platform']
      when /sles-/
        result = exec(Beaker::Command.new("zypper se -i --match-exact #{name}"), :acceptable_exit_codes => (0...127))
      when /el-4/
        @logger.debug("Package query not supported on rhel4")
        return false
      when /fedora|centos|el-/
        result = exec(Beaker::Command.new("rpm -q #{name}"), :acceptable_exit_codes => (0...127))
      when /ubuntu|debian/
        result = exec(Beaker::Command.new("dpkg -s #{name}"), :acceptable_exit_codes => (0...127))
      when /solaris-11/
        result = exec(Beaker::Command.new("pkg info #{name}"), :acceptable_exit_codes => (0...127))
      when /solaris-10/
        result = exec(Beaker::Command.new("pkginfo #{name}"), :acceptable_exit_codes => (0...127))
      when /gentoo/
        result = exec(Beaker::Command.new("ls -d /var/db/pkg/*/* | grep #{name}"), :acceptable_exit_codes => (0...127))
      else
        raise "Package #{name} cannot be queried on #{self}"
    end
    result.exit_code == 0
  end

  # If apt has not been updated since the last repo deployment it is
  # updated. Otherwise this is a noop
  def update_apt_if_needed
    if self['platform'] =~ /debian|ubuntu/
      if @apt_needs_update
        execute("apt-get update")
        @apt_needs_update = false
      end
    end
  end

  # If emerge has not been synced since the last repo deployment it is
  # updated. Otherwise this is a noop
  def sync_emerge_if_needed
    if self['platform'] =~ /gentoo/
      if @emerge_needs_sync
        execute("emerge --sync")
        @emerge_needs_sync = false
      end
    end
  end

  def install_package(name, cmdline_args = '', version = nil)
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive in #{name}")
      when /el-4/
        @logger.debug("Package installation not supported on rhel4")
      when /fedora|centos|el-/
        if version
          name = "#{name}-#{version}"
        end
        execute("yum -y #{cmdline_args} install #{name}")
      when /ubuntu|debian/
        if version
          name = "#{name}=#{version}"
        end
        update_apt_if_needed
        execute("apt-get install --force-yes #{cmdline_args} -y #{name}")
      when /solaris-11/
        execute("pkg #{cmdline_args} install #{name}")
      when /solaris-10/
        execute("pkgutil -i -y #{cmdline_args} #{name}")
      when /gentoo/
        sync_emerge_if_needed
        execute("emerge #{name}")
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  def uninstall_package(name, cmdline_args = '')
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive rm #{name}")
      when /el-4/
        @logger.debug("Package uninstallation not supported on rhel4")
      when /fedora|centos|el-/
        execute("yum -y #{cmdline_args} remove #{name}")
      when /ubuntu|debian/
        execute("apt-get purge #{cmdline_args} -y #{name}")
      when /solaris-11/
        execute("pkg #{cmdline_args} uninstall #{name}")
      when /solaris-10/
        execute("pkgutil -r -y #{cmdline_args} #{name}")
      when /gentoo/
        execute("emerge --unmerge #{name}")
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  # Upgrade an installed package to the latest available version
  #
  # @param [String] name          The name of the package to update
  # @param [String] cmdline_args  Additional command line arguments for
  #                               the package manager
  def upgrade_package(name, cmdline_args = '')
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive --no-gpg-checks up #{name}")
      when /el-4/
        @logger.debug("Package upgrade is not supported on rhel4")
      when /fedora|centos|el-/
        execute("yum -y #{cmdline_args} update #{name}")
      when /ubuntu|debian/
        update_apt_if_needed
        execute("apt-get install -o Dpkg::Options::='--force-confold' #{cmdline_args} -y --force-yes #{name}")
      when /solaris-11/
        execute("pkg #{cmdline_args} update #{name}")
      when /solaris-10/
        execute("pkgutil -u -y #{cmdline_args} ${name}")
      when /gentoo/
        sync_emerge_if_needed
        execute("emerge -uDN #{name}")
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
  # @note See {Beaker::DSL::Helpers#deploy_package_repo} for info on
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
  # @note See {Beaker::DSL::Helpers#deploy_package_repo} for info on
  #       params
  def deploy_yum_repo(path, name, version)
    repo_file = "#{path}/rpm/pl-#{name}-#{version}-repos-pe-#{self['platform']}.repo"
    do_scp_to repo_file, "/etc/yum.repos.d/#{name}.repo", {}
  end

  # Deploy zypper repo configuration generated by the packaging tooling
  #
  # @note See {Beaker::DSL::Helpers#deploy_package_repo} for info on
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
  # @note See {Beaker::DSL::Helpers#deploy_package_repo} for info on
  #       params
  def deploy_package_repo(path, name, version)
    if not File.exists? path
      @logger.warning "Was asked to deploy package repository from #{path}, but it doesn't exist!"
      return
    end

    case self['platform']
      when /el-4/
        @logger.debug("Package repo deploy is not supported on rhel4")
      when /fedora|centos|el-/
        deploy_yum_repo(path, name, version)
      when /ubuntu|debian/
        deploy_apt_repo(path, name, version)
      when /sles/
        deploy_zyp_repo(path, name, version)
      else
        # solaris, windows
        raise "Package repo cannot be deployed on #{self}; the platform is not supported"
    end
  end
end
