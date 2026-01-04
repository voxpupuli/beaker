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
    else # 32 bit version
      rootdir = "c:\\\\cygwin"
      cygwin = "setup-x86.exe"
    end

    execute("#{cygwin} -q -n -N -d -R #{rootdir} -s http://cygwin.osuosl.org -P #{name} #{cmdline_args}")
  end

  def uninstall_package(name, _cmdline_args = '')
    raise "Package #{name} cannot be uninstalled on #{self}"
  end

  # Examine the host system to determine the architecture
  # @return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    identify_windows_architecture.include?('64')
  end

  private

  # @api private
  def identify_windows_architecture
    platform.arch.include?('64') ? '64' : '32'
  end
end
