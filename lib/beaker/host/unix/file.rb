module Unix::File
  include Beaker::CommandFactory

  def tmpfile(name = '', extension = nil)
    execute("mktemp -t #{name}.XXXXXX#{extension}")
  end

  def tmpdir(name = '')
    execute("mktemp -dt #{name}.XXXXXX")
  end

  def system_temp_path
    '/tmp'
  end

  # Change user ownership of a path
  #
  # @see http://pubs.opengroup.org/onlinepubs/9699919799/utilities/chown.html
  #
  # @note To maintain argument order consistency with the underlying
  #   syscall, avoid having to specify nil arguments, and not do
  #   anything hacky with the arguments list, this method does not
  #   allow you to modify group ownership. Use Host::chgrp instead.
  # @param [String] user User to chown to
  # @param [String] path Path to chown
  # @param [Boolean] recursive Whether to pass the recursive flag
  #
  # @return [Beaker::Result] result of command execution
  def chown(user, path, recursive = false)
    execute("chown #{recursive ? '-R ' : ''}#{user} #{path}")
  end

  def chmod(mod, path, recursive = false)
    execute("chmod #{recursive ? '-R ' : ''}#{mod} #{path}")
  end

  # Change group ownership of a path
  #
  # @see http://pubs.opengroup.org/onlinepubs/9699919799/utilities/chgrp.html
  #
  # @param [String] group Group to chgrp to
  # @param [String] path Path to chgrp
  # @param [Boolean] recursive Whether to pass the recursive flag
  #
  # @return [Beaker::Result] result of command execution
  def chgrp(group, path, recursive = false)
    execute("chgrp #{recursive ? '-R ' : ''}#{group} #{path}")
  end

  # List long output of a path
  #
  # @see http://pubs.opengroup.org/onlinepubs/9699919799/utilities/ls.html
  #
  # @param [String] path Path to list properties of
  #
  # @return [Beaker::Result] result of command execution
  def ls_ld(path)
    execute("ls -ld #{path}")
  end

  def cat(path)
    execute("cat #{path}")
  end

  # Handles any changes needed in a path for SCP
  #
  # @param [String] path File path to SCP to
  #
  # @return [String] path, changed if needed due to host
  #   constraints
  def scp_path(path)
    path
  end

  def path_split(paths)
    paths.split(':')
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("test -e #{path}"), :acceptable_exit_codes => [0, 1])
    result.exit_code == 0
  end

  # Gets the config dir location for package information
  #
  # @raise [ArgumentError] For an unknown platform
  #
  # @return [String] Path to package config dir
  def package_config_dir
    case self['platform']
    when /amazon|fedora|el-|redhat|centos/
      '/etc/yum.repos.d/'
    when /opensuse|sles/
      '/etc/zypp/repos.d/'
    when /debian|ubuntu/
      '/etc/apt/sources.list.d'
    else
      msg = "package config dir unknown for platform '#{self['platform']}'"
      raise ArgumentError, msg
    end
  end

  # Returns the repo filename for a given package & version for a platform
  #
  # @param [String] package_name Name of the package
  # @param [String] build_version Version string of the package
  #
  # @raise [ArgumentError] For an unknown platform
  #
  # @return [String] Filename of the repo
  def repo_filename(package_name, build_version)
    variant, version, arch, codename = self['platform'].to_array
    repo_filename = format("pl-%s-%s-", package_name, build_version)

    case variant
    when /amazon|fedora|el|redhat|centos|opensuse|sles/
      variant = 'el' if %w[centos redhat].include?(variant)

      variant = 'redhatfips' if self['packaging_platform']&.include?('redhatfips')

      fedora_prefix = (variant == 'fedora' ? 'f' : '')

      pattern = "%s-%s%s-%s.repo"

      repo_filename << (format(pattern, variant, fedora_prefix, version, arch))
    when /debian|ubuntu/
      repo_filename << (format("%s.list", codename))
    else
      msg = "#repo_filename: repo filename pattern not known for platform '#{self['platform']}'"
      raise ArgumentError, msg
    end

    repo_filename
  end

  # Gets the repo type for the given platform
  #
  # @raise [ArgumentError] For an unknown platform
  #
  # @return [String] Type of repo (rpm|deb)
  def repo_type
    case self['platform']
    when /amazon|fedora|el-|redhat|centos|opensuse|sles/
      'rpm'
    when /debian|ubuntu/
      'deb'
    else
      msg = "#repo_type: repo type not known for platform '#{self['platform']}'"
      raise ArgumentError, msg
    end
  end

  # Returns the noask file text for Solaris hosts
  #
  # @raise [ArgumentError] If called on a host with a platform that's not Solaris
  #
  # @return [String] the text of the noask file
  # @deprecated Use {Beaker::Platform#noask_file_text} instead
  def noask_file_text
    self['platform'].noask_file_text
  end

  protected

  # Handles host operations needed after an SCP takes place
  #
  # @param [String] scp_file_actual File path to actual SCP'd file on host
  # @param [String] scp_file_target File path to target SCP location on host
  #
  # @return nil
  def scp_post_operations(_scp_file_actual, _scp_file_target)
    nil
  end
end
