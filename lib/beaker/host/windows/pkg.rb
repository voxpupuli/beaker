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
    cygwin = ""
    rootdir = ""

    arch = identify_windows_architecture

    if arch == '64'
      rootdir = "c:\\\\cygwin64"
      cygwin = "setup-x86_64.exe"
    else #32 bit version
      rootdir = "c:\\\\cygwin"
      cygwin = "setup-x86.exe"
    end

    if not check_for_command(cygwin)
      command = "curl --retry 5 https://cygwin.com/#{cygwin} -o /cygdrive/c/Windows/System32/#{cygwin}"
      begin
        execute(command)
      rescue Beaker::Host::CommandFailure
        command.sub!('https', 'http')
        execute(command)
      end
    end
    execute("#{cygwin} -q -n -N -d -R #{cmdline_args} #{rootdir} -s http://cygwin.osuosl.org -P #{name}")
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
    release_file = "puppet-agent-x#{arch_suffix}.msi"
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
    arch = nil
    execute("echo '' | wmic os get osarchitecture", :accept_all_exit_codes => true) do |result|
      arch = if result.exit_code == 0
        result.stdout =~ /64/ ? '64' : '32'
      else
        identify_windows_architecture_from_os_name_for_win2003
      end
    end
    arch
  end

  # @api private
  def identify_windows_architecture_from_os_name_for_win2003
    arch = nil
    execute("echo '' | wmic os get name | grep x64", :accept_all_exit_codes => true) do |result|
      arch = result.exit_code == 0 ? '64' : '32'
    end
    arch
  end
end
