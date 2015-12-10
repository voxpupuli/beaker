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
