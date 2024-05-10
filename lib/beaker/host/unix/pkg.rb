module Unix::Pkg
  include Beaker::CommandFactory

  # This method overrides {Beaker::Host#pkg_initialize} to provide
  # unix-specific package management setup
  def pkg_initialize
    @apt_needs_update = true
    @pacman_needs_update = true
  end

  def check_for_command(name)
    result = exec(Beaker::Command.new("which #{name}"), :accept_all_exit_codes => true)
    case self['platform']
    when /solaris-10/
      # solaris 10 appears to have considered `which` to have run successfully,
      # even if the command didn't exist, so it'll return a 0 exit code in
      # either case. Instead we match for the phrase output when a match isn't
      # found: "no #{name} in $PATH", reversing it to match our API
      !(result.stdout.match(/^no\ #{name}\ in\ /))
    else
      result.exit_code == 0
    end
  end

  def check_for_package(name, opts = {})
    opts = { :accept_all_exit_codes => true }.merge(opts)
    case self['platform']
    when /sles-10/
      result = execute("zypper se -i --match-exact #{name}", opts) { |result| result }
      result.stdout.include?('No packages found') ? (return false) : (return result.exit_code == 0)
    when /opensuse|sles-/
      if !self[:sles_rpmkeys_nightly_pl_imported]
        # The `:sles_rpmkeys_nightly_pl_imported` key is only read here at this
        # time. It's just to make sure that we only do the key import once, &
        # isn't for setting or use outside of beaker.
        execute('rpmkeys --import http://nightlies.puppetlabs.com/07BB6C57', opts)
        self[:sles_rpmkeys_nightly_pl_imported] = true
      end
      result = execute("zypper --gpg-auto-import-keys se -i --match-exact #{name}", opts) { |result| result }
    when /amazon|cisco|fedora|centos|redhat|eos|el-/
      result = execute("rpm -q #{name}", opts) { |result| result }
    when /ubuntu|debian/
      result = execute("dpkg -s #{name}", opts) { |result| result }
    when /solaris-11/
      result = execute("pkg info #{name}", opts) { |result| result }
    when /solaris-10/
      result = execute("pkginfo #{name}", opts) { |result| result }
      result = execute("pkginfo CSW#{name}", opts) { |result| result } if result.exit_code == 1
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
    return unless /debian|ubuntu/.match?(self['platform'])
    return unless @apt_needs_update

    execute("apt-get update")
    @apt_needs_update = false
  end

  # Arch Linux is a rolling release distribution. We need to ensure that it is up2date
  # Except for the kernel. An upgrade will purge the modules for the currently running kernel
  # Before upgrading packages, we need to ensure we've the latest keyring
  def update_pacman_if_needed
    return unless self['platform'].include?('archlinux')
    return unless @pacman_needs_update

    execute("pacman --sync --noconfirm --noprogressbar --refresh archlinux-keyring")
    execute("pacman --sync --noconfirm --noprogressbar --refresh --sysupgrade --ignore linux --ignore linux-docs --ignore linux-headers")
    @pacman_needs_update = false
  end

  def install_package(name, cmdline_args = '', version = nil, opts = {})
    case self['platform']
    when /opensuse|sles-/
      execute("zypper --non-interactive --gpg-auto-import-keys in #{name}", opts)
    when /amazon-2023|el-(8|9|1[0-9])|fedora/
      name = "#{name}-#{version}" if version
      execute("dnf -y #{cmdline_args} install #{name}", opts)
    when /cisco|centos|redhat|eos|el-[1-7]-/
      name = "#{name}-#{version}" if version
      execute("yum -y #{cmdline_args} install #{name}", opts)
    when /ubuntu|debian/
      name = "#{name}=#{version}" if version
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
      if !check_for_command('pkgutil')
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
          if (match = /^Ambiguous: #{name} could be (.+)$/.match(command.stderr))
            name = match[1].chomp.split(' ').collect do |x|
              # FIXME: Ruby 3.2 compatibility?
              x =~ /-(\d[^-p]+)/
              [x, $1]
            end.select do |x|
              # Blacklist Ruby 2.2.0+ for the sake of Puppet 3.x
              Gem::Version.new(x[1]) < Gem::Version.new('2.2.0')
            end.sort do |a, b|
              Gem::Version.new(b[1]) <=> Gem::Version.new(a[1])
            end.collect do |x|
              x[0]
            end.first
            raise ArgumentException
          end
          # If the package advises symlinks to be created, do it
          command.stdout.split("\n").select { |x| /^\s+ln\s/.match?(x) }.each do |ln|
            execute(ln, opts)
          end
        end
      rescue
        retry
      end
    when /archlinux/
      update_pacman_if_needed
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
    proxy = extract_rpm_proxy_options(opts[:package_proxy]) if name&.start_with?('http') and opts[:package_proxy]
    execute("rpm #{cmdline_args} -Uvh #{name} #{proxy}")
  end

  def uninstall_package(name, cmdline_args = '', opts = {})
    case self['platform']
    when /opensuse|sles-/
      execute("zypper --non-interactive rm #{name}", opts)
    when /amazon-2023|el-(8|9|1[0-9])|fedora/
      execute("dnf -y #{cmdline_args} remove #{name}", opts)
    when /cisco|centos|redhat|eos|el-[1-7]-/
      execute("yum -y #{cmdline_args} remove #{name}", opts)
    when /ubuntu|debian/
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
    when /opensuse|sles-/
      execute("zypper --non-interactive --no-gpg-checks up #{name}", opts)
    when /fedora-(2[2-9]|3[0-9])/
      execute("dnf -y #{cmdline_args} update #{name}", opts)
    when /cisco|fedora|centos|redhat|eos|el-/
      execute("yum -y #{cmdline_args} update #{name}", opts)
    when /ubuntu|debian/
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

  # Examine the host system to determine the architecture
  # @return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    if self[:platform].include?('solaris')
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
      host, port = url.match(/https?:\/\/(.*):(\d*)/)[1, 2]
      raise if host.empty? or port.empty?

      "--httpproxy #{host} --httpport #{port}"
    rescue
      raise "Cannot extract host and port from '#{url}'"
    end
  end

  # Installs a package already located on a SUT
  #
  # @param [String] onhost_package_file Path to the package file to install
  # @param [String] onhost_copy_dir Path to the directory where the package
  #                                 file is located. Used on solaris only
  #
  # @return nil
  def install_local_package(onhost_package_file, onhost_copy_dir = nil)
    variant, version, _arch, _codename = self['platform'].to_array
    case variant
    when /^(amazon|fedora|el|redhat|centos)$/
      command_name = 'yum'
      command_name = 'dnf' if (variant == 'fedora' && version.to_i > 21) || (variant == 'amazon' && version.to_i >= 2023)
      execute("#{command_name} --nogpgcheck localinstall -y #{onhost_package_file}")
    when /^(opensuse|sles)$/
      execute("zypper --non-interactive --no-gpg-checks in #{onhost_package_file}")
    when /^(debian|ubuntu)$/
      execute("dpkg -i --force-all #{onhost_package_file}")
      execute("apt-get update")
    when /^solaris$/
      self.solaris_install_local_package(onhost_package_file, onhost_copy_dir)
    when /^osx$/
      install_package(onhost_package_file)
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
    variant, version, _arch, _codename = self['platform'].to_array
    case variant
    when /^(amazon|fedora|el|centos|redhat|opensuse|sles|debian|ubuntu)$/
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
    variant, version, _arch, _codename = self['platform'].to_array

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
