module Unix::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("mktemp -t #{name}.XXXXXX")
  end

  def tmpdir(name)
    execute("mktemp -dt #{name}.XXXXXX")
  end

  def system_temp_path
    '/tmp'
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
    when /fedora|el-|centos/
      '/etc/yum.repos.d/'
    when /debian|ubuntu|cumulus/
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
    repo_filename = "pl-%s-%s-" % [ package_name, build_version ]

    case variant
    when /fedora|el|centos|cisco_nexus|cisco_ios_xr/
      variant = 'el' if variant == 'centos'
      if variant == 'cisco_nexus'
        variant = 'cisco-wrlinux'
        version = '5'
      end
      if variant == 'cisco_ios_xr'
        variant = 'cisco-wrlinux'
        version = '7'
      end
      fedora_prefix = ((variant == 'fedora') ? 'f' : '')

      pattern = "%s-%s%s-%s.repo"
      pattern = "repos-pe-#{pattern}" if self.is_pe?

      repo_filename << pattern % [
        variant,
        fedora_prefix,
        version,
        arch
      ]
    when /debian|ubuntu|cumulus/
      codename = variant if variant == 'cumulus'
      repo_filename << "%s.list" % [ codename ]
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
    when /fedora|el-|centos/
      'rpm'
    when /debian|ubuntu|cumulus/
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
  def noask_file_text
    variant, version, arch, codename = self['platform'].to_array
    if variant == 'solaris' && version == '10'
      noask = <<NOASK
# Write the noask file to a temporary directory
# please see man -s 4 admin for details about this file:
# http://www.opensolarisforum.org/man/man4/admin.html
#
# The key thing we don't want to prompt for are conflicting files.
# The other nocheck settings are mostly defensive to prevent prompts
# We _do_ want to check for available free space and abort if there is
# not enough
mail=
# Overwrite already installed instances
instance=overwrite
# Do not bother checking for partially installed packages
partial=nocheck
# Do not bother checking the runlevel
runlevel=nocheck
# Do not bother checking package dependencies (We take care of this)
idepend=nocheck
rdepend=nocheck
# DO check for available free space and abort if there isn't enough
space=quit
# Do not check for setuid files.
setuid=nocheck
# Do not check if files conflict with other packages
conflict=nocheck
# We have no action scripts.  Do not check for them.
action=nocheck
# Install to the default base directory.
basedir=default
NOASK
    else
      msg = "noask file text unknown for platform '#{self['platform']}'"
      raise ArgumentError, msg
    end
    noask
  end

  protected

  # Handles host operations needed after an SCP takes place
  #
  # @param [String] scp_file_actual File path to actual SCP'd file on host
  # @param [String] scp_file_target File path to target SCP location on host
  #
  # @return nil
  def scp_post_operations(scp_file_actual, scp_file_target)
    nil
  end
end
