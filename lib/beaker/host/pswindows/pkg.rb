module PSWindows::Pkg
  include Beaker::CommandFactory

  def check_for_command(name)
    result = exec(Beaker::Command.new("where #{name}"), :accept_all_exit_codes => true)
    result.exit_code == 0
  end

  def check_for_package(_name)
    #HACK NOOP
    #raise "Cannot check for package #{name} on #{self}"
    0
  end

  def install_package(_name, _cmdline_args = '')
    #HACK NOOP
    #raise "Package #{name} cannot be installed on #{self}"
    0
  end

  def uninstall_package(_name, _cmdline_args = '')
    #HACK NOOP
    #raise "Package #{name} cannot be uninstalled on #{self}"
    0
  end

  #Examine the host system to determine the architecture, overrides default host determine_if_x86_64 so that wmic is used
  #@return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    identify_windows_architecture.include?('64')
  end

  private

  # @api private
  def identify_windows_architecture
    arch = nil
    execute("wmic os get osarchitecture", :accept_all_exit_codes => true) do |result|
      arch = if result.exit_code == 0
        result.stdout.include?('64') ? '64' : '32'
      else
        identify_windows_architecture_from_os_name_for_win2003
      end
    end
    arch
  end

  # @api private
  def identify_windows_architecture_from_os_name_for_win2003
    arch = nil
    execute("wmic os get name", :accept_all_exit_codes => true) do |result|
      arch = result.stdout.include?('64') ? '64' : '32'
    end
    arch
  end
end
