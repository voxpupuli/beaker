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
      # solaris 10 appears to have considered `which` to have run successfully,
      # even if the command didn't exist, so it'll return a 0 exit code in
      # either case. Instead we match for the phrase output when a match isn't
      # found: "no #{name} in $PATH", reversing it to match our API
      !( result.stdout.match(/^no\ #{name}\ in\ /) )
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
        if !self[:sles_rpmkeys_nightly_pl_imported]
          # The `:sles_rpmkeys_nightly_pl_imported` key is only read here at this
          # time. It's just to make sure that we only do the key import once, &
          # isn't for setting or use outside of beaker.
          execute('rpmkeys --import http://nightlies.puppetlabs.com/07BB6C57', opts)
          self[:sles_rpmkeys_nightly_pl_imported] = true
        end
        result = execute("zypper --gpg-auto-import-keys se -i --match-exact #{name}", opts) { |result| result }
      when /el-4/
        @logger.debug("Package query not supported on rhel4")
        return false
      when /cisco|fedora|centos|eos|el-/
        result = execute("rpm -q #{name}", opts) { |result| result }
      when /ubuntu|debian|cumulus|huaweios/
        result = execute("dpkg -s #{name}", opts) { |result| result }
      when /solaris-11/
        result = execute("pkg info #{name}", opts) { |result| result }
      when /solaris-10/
        result = execute("pkginfo #{name}", opts) { |result| result }
        if result.exit_code == 1
          result = execute("pkginfo CSW#{name}", opts) { |result| result }
        end
      when /openbsd/
        result = execute("pkg_info #{name}", opts) { |result| result }
      when /archlinux/
        result = execute("pacman -Q #{name}", opts) { |result| result }
      else
        raise "Package #{name} cannot be queried on #{self}"
    end
    result.exit_code == 0
  end

  # If apt has not been updated since the last repo deployment it is
  # updated. Otherwise this is a noop
  def update_apt_if_needed
    if self['platform'] =~ /debian|ubuntu|cumulus|huaweios/
      if @apt_needs_update
        execute("apt-get update")
        @apt_needs_update = false
      end
    end
  end

  def install_package(name, cmdline_args = '', version = nil, opts = {})
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive --gpg-auto-import-keys in #{name}", opts)
      when /el-4/
        @logger.debug("Package installation not supported on rhel4")
      when /fedora-(2[2-9])/
        if version
          name = "#{name}-#{version}"
        end
        execute("dnf -y #{cmdline_args} install #{name}", opts)
      when /cisco|fedora|centos|eos|el-/
        if version
          name = "#{name}-#{version}"
        end
        execute("yum -y #{cmdline_args} install #{name}", opts)
      when /ubuntu|debian|cumulus|huaweios/
        if version
          name = "#{name}=#{version}"
        end
        update_apt_if_needed
        execute("apt-get install --force-yes #{cmdline_args} -y #{name}", opts)
      when /solaris-11/
        if opts[:acceptable_exit_codes]
          opts[:acceptable_exit_codes] << 4
        else
          opts[:acceptable_exit_codes] = [0, 4] unless opts[:accept_all_exit_codes]
        end
        execute("pkg #{cmdline_args} install #{name}", opts)
      when /solaris-10/
        if ! check_for_command('pkgutil')
          # https://www.opencsw.org/package/pkgutil/
          noask_text = self.noask_file_text
          noask_file = File.join(external_copy_base, 'noask')
          create_remote_file(self, noask_file, noask_text)
          execute("pkgadd -d http://get.opencsw.org/now -a #{noask_file} -n all", opts)
          execute('/opt/csw/bin/pkgutil -U', opts)
          execute('/opt/csw/bin/pkgutil -y -i pkgutil', opts)
        end
        execute("pkgutil -i -y #{cmdline_args} #{name}", opts)
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
      when /archlinux/
        execute("pacman -S --noconfirm #{cmdline_args} #{name}", opts)
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  # Install a package using RPM
  #
  # @param [String] name          The name of the package to install.  It
  #                               may be a filename or a URL.
  # @param [String] cmdline_args  Additional command line arguments for
  #                               the package manager.
  # @option opts [String] :package_proxy  A proxy of form http://host:port
  #
  # @return nil
  # @api public
  def install_package_with_rpm(name, cmdline_args = '', opts = {})
    proxy = ''
    if name =~ /^http/ and opts[:package_proxy]
      proxy = extract_rpm_proxy_options(opts[:package_proxy])
    end
    execute("rpm #{cmdline_args} -Uvh #{name} #{proxy}")
  end

  def uninstall_package(name, cmdline_args = '', opts = {})
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive rm #{name}", opts)
      when /el-4/
        @logger.debug("Package uninstallation not supported on rhel4")
      when /edora-(2[2-9])/
        execute("dnf -y #{cmdline_args} remove #{name}", opts)
      when /cisco|fedora|centos|eos|el-/
        execute("yum -y #{cmdline_args} remove #{name}", opts)
      when /ubuntu|debian|cumulus|huaweios/
        execute("apt-get purge #{cmdline_args} -y #{name}", opts)
      when /solaris-11/
        execute("pkg #{cmdline_args} uninstall #{name}", opts)
      when /solaris-10/
        execute("pkgrm -n #{cmdline_args} #{name}", opts)
      when /aix/
        execute("rpm #{cmdline_args} -e #{name}", opts)
      when /archlinux/
        execute("pacman -R --noconfirm #{cmdline_args} #{name}", opts)
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
      when /fedora-(2[2-9])/
        execute("dnf -y #{cmdline_args} update #{name}", opts)
      when /cisco|fedora|centos|eos|el-/
        execute("yum -y #{cmdline_args} update #{name}", opts)
      when /ubuntu|debian|cumulus|huaweios/
        update_apt_if_needed
        execute("apt-get install -o Dpkg::Options::='--force-confold' #{cmdline_args} -y --force-yes #{name}", opts)
      when /solaris-11/
        if opts[:acceptable_exit_codes]
          opts[:acceptable_exit_codes] << 4
        else
          opts[:acceptable_exit_codes] = [0, 4] unless opts[:accept_all_exit_codes]
        end
        execute("pkg #{cmdline_args} update #{name}", opts)
      when /solaris-10/
        execute("pkgutil -u -y #{cmdline_args} #{name}", opts)
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
      @logger.warn "Could not determine codename for debian platform #{self['platform']}. Skipping deployment of repo #{name}"
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
      @logger.warn "Was asked to deploy package repository from #{path}, but it doesn't exist!"
      return
    end

    case self['platform']
      when /el-4/
        @logger.debug("Package repo deploy is not supported on rhel4")
      when /fedora|centos|eos|el-/
        deploy_yum_repo(path, name, version)
      when /ubuntu|debian|cumulus|huaweios/
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

  # Extract RPM command's proxy options from URL
  #
  # @param [String] url  A URL of form http://host:port
  # @return [String]     httpproxy and httport options for rpm
  #
  # @raise [StandardError] When encountering a string that
  #                        cannot be parsed
  # @api private
  def extract_rpm_proxy_options(url)
    begin
      host, port = url.match(/https?:\/\/(.*):(\d*)/)[1,2]
      raise if host.empty? or port.empty?
      "--httpproxy #{host} --httpport #{port}"
    rescue
      raise "Cannot extract host and port from '#{url}'"
    end
  end

  # Gets the path & file name for the puppet agent dev package on Unix
  #
  # @param [String] puppet_collection Name of the puppet collection to use
  # @param [String] puppet_agent_version Version of puppet agent to get
  # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
  #
  # @note Solaris does require :download_url to be set on the opts argument
  #   in order to check for builds on the builds server
  #
  # @raise [ArgumentError] If one of the two required parameters (puppet_collection,
  #   puppet_agent_version) is either not passed or set to nil
  #
  # @return [String, String] Path to the directory and filename of the package, respectively
  def solaris_puppet_agent_dev_package_info( puppet_collection = nil, puppet_agent_version = nil, opts = {} )
    error_message = "Must provide %s argument to get puppet agent package information"
    raise ArgumentError, error_message % "puppet_collection" unless puppet_collection
    raise ArgumentError, error_message % "puppet_agent_version" unless puppet_agent_version
    raise ArgumentError, error_message % "opts[:download_url]" unless opts[:download_url]

    variant, version, arch, codename = self['platform'].to_array

    version = version.split('.')[0] # packages are only published for major versions

    platform_error = "Incorrect platform '#{variant}' for #solaris_puppet_agent_dev_package_info"
    raise ArgumentError, platform_error if variant != 'solaris'

    if arch == 'x86_64'
      arch = 'i386'
    end
    release_path_end = "solaris/#{version}/#{puppet_collection}"
    solaris_revision_conjunction = '-'
    revision = '1'
    if version == '10'
      solaris_release_version = ''
      pkg_suffix = 'pkg.gz'
      solaris_name_conjunction = '-'
      component_version = puppet_agent_version
    elsif version == '11'
      # Ref:
      # http://www.oracle.com/technetwork/articles/servers-storage-admin/ips-package-versioning-2232906.html
      #
      # Example to show package name components:
      #   Full package name: puppet-agent@1.2.5.38.6813,5.11-1.sparc.p5p
      #   Schema: <component-name><solaris_name_conjunction><component_version><solaris_release_version><solaris_revision_conjunction><revision>.<arch>.<pkg_suffix>
      solaris_release_version = ',5.11' # injecting comma to prevent from adding another var
      pkg_suffix = 'p5p'
      solaris_name_conjunction = '@'
      component_version = puppet_agent_version.dup
      component_version.gsub!(/[a-zA-Z]/, '')
      component_version.gsub!(/(^-)|(-$)/, '')
      # Here we strip leading 0 from version components but leave
      # singular 0 on their own.
      component_version = component_version.split('-').join('.')
      component_version = component_version.split('.').map(&:to_i).join('.')
    end
    release_file_base = "puppet-agent#{solaris_name_conjunction}#{component_version}#{solaris_release_version}"
    release_file_end = "#{arch}.#{pkg_suffix}"
    release_file = "#{release_file_base}#{solaris_revision_conjunction}#{revision}.#{release_file_end}"
    if not link_exists?("#{opts[:download_url]}/#{release_path_end}/#{release_file}")
      release_file = "#{release_file_base}.#{release_file_end}"
    end
    return release_path_end, release_file
  end

  # Gets the path & file name for the puppet agent dev package on Unix
  #
  # @param [String] puppet_collection Name of the puppet collection to use
  # @param [String] puppet_agent_version Version of puppet agent to get
  # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
  #
  # @note Solaris & OSX do require some options to be set. See
  #   {#solaris_puppet_agent_dev_package_info} &
  #   {Mac::Pkg#puppet_agent_dev_package_info} for more details
  #
  # @raise [ArgumentError] If one of the two required parameters (puppet_collection,
  #   puppet_agent_version) is either not passed or set to nil
  #
  # @return [String, String] Path to the directory and filename of the package, respectively
  def puppet_agent_dev_package_info( puppet_collection = nil, puppet_agent_version = nil, opts = {} )
    error_message = "Must provide %s argument to get puppet agent dev package information"
    raise ArgumentError, error_message % "puppet_collection" unless puppet_collection
    raise ArgumentError, error_message % "puppet_agent_version" unless puppet_agent_version

    variant, version, arch, codename = self['platform'].to_array
    case variant
    when /^(solaris)$/
      release_path_end, release_file = solaris_puppet_agent_dev_package_info(
        puppet_collection, puppet_agent_version, opts )
    when /^(sles|aix|el|centos|oracle|redhat|scientific)$/
      variant = 'el' if variant.match(/(?:el|centos|oracle|redhat|scientific)/)
      arch = 'ppc' if variant == 'aix' && arch == 'power'
      version = '7.1' if variant == 'aix' && version == '7.2'
      release_path_end = "#{variant}/#{version}/#{puppet_collection}/#{arch}"
      release_file = "puppet-agent-#{puppet_agent_version}-1.#{variant}#{version}.#{arch}.rpm"
    else
      msg = "puppet_agent dev package info unknown for platform '#{self['platform']}'"
      raise ArgumentError, msg
    end
    return release_path_end, release_file
  end

  # Gets host-specific information for PE promoted puppet-agent packages
  #
  # @param [String] puppet_collection Name of the puppet collection to use
  # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
  #
  # @return [String, String, String] Host-specific information for packages
  #   1. release_path_end Suffix for the release_path. Used on Windows. Check
  #   {Windows::Pkg#pe_puppet_agent_promoted_package_info} to see usage.
  #   2. release_file Path to the file on release build servers
  #   3. download_file Filename for the package itself
  def pe_puppet_agent_promoted_package_info( puppet_collection = nil, opts = {} )
    error_message = "Must provide %s argument to get puppet agent dev package information"
    raise ArgumentError, error_message % "puppet_collection" unless puppet_collection

    variant, version, arch, codename = self['platform'].to_array
    case variant
    when /^(fedora|el|centos|sles)$/
      variant = ((variant == 'centos') ? 'el' : variant)
      release_file = "/repos/#{variant}/#{version}/#{puppet_collection}/#{arch}/puppet-agent-*.rpm"
      download_file = "puppet-agent-#{variant}-#{version}-#{arch}.tar.gz"
    when /^(debian|ubuntu|cumulus)$/
      if arch == 'x86_64'
        arch = 'amd64'
      end
      version = version[0,2] + '.' + version[2,2] if (variant =~ /ubuntu/ && !version.include?("."))
      release_file = "/repos/apt/#{codename}/pool/#{puppet_collection}/p/puppet-agent/puppet-agent*#{arch}.deb"
      download_file = "puppet-agent-#{variant}-#{version}-#{arch}.tar.gz"
    when /^solaris$/
      if arch == 'x86_64'
        arch = 'i386'
      end
      release_file = "/repos/solaris/#{version}/#{puppet_collection}/"
      download_file = "puppet-agent-#{variant}-#{version}-#{arch}.tar.gz"
    else
      raise "No pe-promoted installation step for #{variant} yet..."
    end
    return '', release_file, download_file
  end

  # Installs a given PE promoted package on a host
  #
  # @param [String] onhost_copy_base Base copy directory on the host
  # @param [String] onhost_copied_download Downloaded file path on the host
  # @param [String] onhost_copied_file Copied file path once un-compressed
  # @param [String] download_file File name of the downloaded file
  # @param [Hash{Symbol=>String}] opts additional options
  #
  # @return nil
  def pe_puppet_agent_promoted_package_install(
    onhost_copy_base, onhost_copied_download, onhost_copied_file, download_file, opts
  )
    uncompress_local_tarball( onhost_copied_download, onhost_copy_base, download_file )
    if self['platform'] =~ /^solaris/
      # above uncompresses the install from .tar.gz -> .p5p into the
      # onhost_copied_file directory w/a weird name. We have to read that file
      # name from the filesystem, so that we can provide it to install_local...
      pkg_filename = execute( "ls #{onhost_copied_file}" )
      onhost_copied_file = "#{onhost_copied_file}#{pkg_filename}"
    end

    install_local_package( onhost_copied_file, onhost_copy_base )
    nil
  end

  # Installs a package already located on a SUT
  #
  # @param [String] onhost_package_file Path to the package file to install
  # @param [String] onhost_copy_dir Path to the directory where the package
  #                                 file is located. Used on solaris only
  #
  # @return nil
  def install_local_package(onhost_package_file, onhost_copy_dir = nil)
    variant, version, arch, codename = self['platform'].to_array
    case variant
    when /^(fedora|el|centos)$/
      command_name = 'yum'
      command_name = 'dnf 'if variant == 'fedora' && version > 21 && version <= 29
      execute("#{command_name} --nogpgcheck localinstall -y #{onhost_package_file}")
    when /^(sles)$/
      execute("rpm -ihv #{onhost_package_file}")
    when /^(debian|ubuntu|cumulus)$/
      execute("dpkg -i --force-all #{onhost_package_file}")
      execute("apt-get update")
    when /^solaris$/
      self.solaris_install_local_package( onhost_package_file, onhost_copy_dir )
    when /^osx$/
      install_package( onhost_package_file )
    else
      msg = "Platform #{variant} is not supported by the method "
      msg << 'install_local_package'
      raise ArgumentError, msg
    end
  end

  # Uncompresses a tarball on the SUT
  #
  # @param [String] onhost_tar_file Path to the tarball to uncompress
  # @param [String] onhost_base_dir Path to the directory to uncompress to
  # @param [String] download_file Name of the file after uncompressing
  #
  # @return nil
  def uncompress_local_tarball(onhost_tar_file, onhost_base_dir, download_file)
    variant, version, arch, codename = self['platform'].to_array
    case variant
    when /^(fedora|el|centos|sles|debian|ubuntu|cumulus)$/
      execute("tar -zxvf #{onhost_tar_file} -C #{onhost_base_dir}")
    when /^solaris$/
      # uncompress PE puppet-agent tarball
      if version == '10'
        execute("gunzip #{onhost_tar_file}")
        tar_file_name = File.basename(download_file, '.gz')
        execute("tar -xvf #{tar_file_name}")
      elsif version == '11'
        execute("tar -zxvf #{onhost_tar_file}")
      else
        msg = "Solaris #{version} is not supported by the method "
        msg << 'uncompress_local_tarball'
        raise ArgumentError, msg
      end
    else
      msg = "Platform #{variant} is not supported by the method "
      msg << 'uncompress_local_tarball'
      raise ArgumentError, msg
    end
  end

  # Installs a local package file on a solaris host
  #
  # @param [String] package_path Path to the package file on the host
  # @param [String] noask_directory Path to the directory for the noask file
  #   (only needed for solaris 10).
  #
  # @return [Beaker::Result] Result of installation command execution
  def solaris_install_local_package(package_path, noask_directory = nil)
    variant, version, arch, codename = self['platform'].to_array

    version = version.split('.')[0] # packages are only published for major versions

    error_message = nil
    unless variant == 'solaris'
      error_message = "Can not call solaris_install_local_package for the "
      error_message << "non-solaris platform '#{variant}'"
    end
    if version != '10' && version != '11'
      error_message = "Solaris #{version} is not supported by the method "
      error_message << 'solaris_install_local_package'
    end
    raise ArgumentError, error_message if error_message

    if version == '10'
      noask_text = self.noask_file_text
      create_remote_file self, File.join(noask_directory, 'noask'), noask_text

      install_cmd = "gunzip -c #{package_path} | pkgadd -d /dev/stdin -a noask -n all"
    elsif version == '11'
      install_cmd = "pkg install -g #{package_path} puppet-agent"
    end
    self.exec(Beaker::Command.new(install_cmd))
  end
end
