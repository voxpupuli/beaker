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
    result.exit_code == 0
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
    when /amazon|fedora|centos|redhat|el-/
      result = execute("rpm -q #{name}", opts) { |result| result }
    when /ubuntu|debian/
      result = execute("dpkg -s #{name}", opts) { |result| result }
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

    # -qq: Only output errors to stdout
    execute("apt-get update -qq")
    @apt_needs_update = false
  end

  # Arch Linux is a rolling release distribution. We need to ensure that it is up2date
  # Except for the kernel. An upgrade will purge the modules for the currently running kernel
  # Before upgrading packages, we need to ensure we've the latest keyring
  def update_pacman_if_needed
    return unless self['platform'].include?('archlinux')
    return unless @pacman_needs_update

    # creates a GPG key + local keyring
    execute("pacman-key --init")
    # `archlinux-keyring` contains GPG keys that will be imported into the local keyring
    # used to verify package signatures
    execute("pacman --sync --noconfirm --noprogressbar --refresh archlinux-keyring")
    execute("pacman --sync --noconfirm --noprogressbar --refresh --sysupgrade --ignore linux --ignore linux-docs --ignore linux-headers")
    @pacman_needs_update = false
  end

  def install_package(name, cmdline_args = '', version = nil, opts = {})
    case self['platform']
    when /opensuse|sles-/
      execute("zypper --non-interactive --gpg-auto-import-keys in #{name}", opts)
    when /amazon(fips)?-2023|el-(8|9|1[0-9])|fedora/
      name = "#{name}-#{version}" if version
      execute("dnf -y #{cmdline_args} install #{name}", opts)
    when /amazon-(2|7)|centos|redhat|el-[1-7]-/
      name = "#{name}-#{version}" if version
      execute("yum -y #{cmdline_args} install #{name}", opts)
    when /ubuntu|debian/
      name = "#{name}=#{version}" if version
      update_apt_if_needed
      execute("apt-get install --force-yes #{cmdline_args} -y #{name}", opts)
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
    when /amazon(fips)?-2023|el-(8|9|1[0-9])|fedora/
      execute("dnf -y #{cmdline_args} remove #{name}", opts)
    when /amazon-(2|7)|centos|redhat|el-[1-7]-/
      execute("yum -y #{cmdline_args} remove #{name}", opts)
    when /ubuntu|debian/
      execute("apt-get purge #{cmdline_args} -y #{name}", opts)
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
    when /fedora/
      execute("dnf -y #{cmdline_args} update #{name}", opts)
    when /centos|redhat|el-/
      execute("yum -y #{cmdline_args} update #{name}", opts)
    when /ubuntu|debian/
      update_apt_if_needed
      execute("apt-get install -o Dpkg::Options::='--force-confold' #{cmdline_args} -y --force-yes #{name}", opts)
    else
      raise "Package #{name} cannot be upgraded on #{self}"
    end
  end

  # Examine the host system to determine the architecture
  # @return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    result = exec(Beaker::Command.new("arch | grep x86_64"), :accept_all_exit_codes => true)
    result.exit_code == 0
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
  #
  # @return nil
  def install_local_package(onhost_package_file)
    variant, version, _arch, _codename = self['platform'].to_array
    case variant
    when /^(amazon(fips)?|fedora|el|redhat|centos)$/
      command_name = 'yum'
      command_name = 'dnf' if (variant == 'fedora' && version.to_i > 21) || (variant == 'amazon' && version.to_i >= 2023)
      execute("#{command_name} --nogpgcheck localinstall -y #{onhost_package_file}")
    when /^(opensuse|sles)$/
      execute("zypper --non-interactive --no-gpg-checks in #{onhost_package_file}")
    when /^(debian|ubuntu)$/
      execute("dpkg -i --force-all #{onhost_package_file}")
      # -qq: Only output errors to stdout
      execute("apt-get update -qq")
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
  #
  # @return nil
  def uncompress_local_tarball(onhost_tar_file, onhost_base_dir)
    case self['platform'].variant
    when /^(amazon(fips)?|fedora|el|centos|redhat|opensuse|sles|debian|ubuntu)$/
      execute("tar -zxvf #{onhost_tar_file} -C #{onhost_base_dir}")
    else
      msg = "Platform #{variant} is not supported by the method "
      msg << 'uncompress_local_tarball'
      raise ArgumentError, msg
    end
  end
end
