module Windows::Pkg
  include Beaker::CommandFactory

  def check_for_command(name)
    result = exec(Beaker::Command.new("which #{name}"), :accept_all_exit_codes => true)
    result.exit_code == 0
  end

  def check_for_package(name)
    result = exec(Beaker::Command.new("cygcheck #{name}"), :accept_all_exit_codes => true)
    result.exit_code == 0
  end

  def install_package(name, cmdline_args = '')
    arch = identify_windows_architecture

    if arch == '64'
      rootdir = "c:\\\\cygwin64"
      cygwin = "setup-x86_64.exe"
    else #32 bit version
      rootdir = "c:\\\\cygwin"
      cygwin = "setup-x86.exe"
    end

    execute("#{cygwin} -q -n -N -d -R #{rootdir} -s http://cygwin.osuosl.org -P #{name} #{cmdline_args}")
  end

  def uninstall_package(name, cmdline_args = '')
    raise "Package #{name} cannot be uninstalled on #{self}"
  end

  #Examine the host system to determine the architecture, overrides default host determine_if_x86_64 so that wmic is used
  #@return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    (identify_windows_architecture =~ /64/) == 0
  end

  # Gets the path & file name for the puppet agent dev package on Windows
  #
  # @param [String] puppet_collection Name of the puppet collection to use
  # @param [String] puppet_agent_version Version of puppet agent to get
  # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
  #
  # @note Windows only uses the 'install_32' option of the opts hash at this
  #   time. Note that it will not fail if not provided, however
  #
  # @return [String, String] Path to the directory and filename of the package, respectively
  def puppet_agent_dev_package_info( puppet_collection = nil, puppet_agent_version = nil, opts = {} )
    release_path_end = 'windows'
    is_config_32 = self['ruby_arch'] == 'x86' || self['install_32'] || opts['install_32']
    should_install_64bit = self.is_x86_64? && !is_config_32
    # only install 64bit builds if
    # - we do not have install_32 set on host
    # - we do not have install_32 set globally
    arch_suffix = should_install_64bit ? '64' : '86'
    # If a version was specified, use it; otherwise fall back to a default name.
    # Avoid when puppet_agent_version is set to a SHA, which isn't used in package names.
    if puppet_agent_version =~ /^\d+\.\d+\.\d+/
      release_file = "puppet-agent-#{puppet_agent_version}-x#{arch_suffix}.msi"
    else
      release_file = "puppet-agent-x#{arch_suffix}.msi"
    end
    return release_path_end, release_file
  end

  # Gets host-specific information for PE promoted puppet-agent packages
  #
  # @param [String] puppet_collection Name of the puppet collection to use
  # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
  #
  # @return [String, String, String] Host-specific information for packages
  #   1. release_path_end Suffix for the release_path
  #   2. release_file Path to the file on release build servers
  #   3. download_file Filename for the package itself
  def pe_puppet_agent_promoted_package_info( puppet_collection = nil, opts = {} )
    is_config_32 = self['ruby_arch'] == 'x86' || self['install_32'] || self['install_32']
    should_install_64bit = self.is_x86_64? && !is_config_32
    # only install 64bit builds if
    # - we do not have install_32 set on host
    # - we do not have install_32 set globally
    arch_suffix = should_install_64bit ? '64' : '86'
    release_path_end = "/windows"
    release_file = "/puppet-agent-x#{arch_suffix}.msi"
    download_file = "puppet-agent-x#{arch_suffix}.msi"
    return release_path_end, release_file, download_file
  end

  private

  # @api private
  def identify_windows_architecture
    platform.arch =~ /64/ ? '64' : '32'
  end

end
