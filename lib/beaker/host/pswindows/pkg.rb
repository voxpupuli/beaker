module PSWindows::Pkg
  include Beaker::CommandFactory

  def check_for_command(name)
    result = exec(Beaker::Command.new("where #{name}"), :acceptable_exit_codes => (0...127))
    result.exit_code == 0
  end

  def check_for_package(name)
    #HACK NOOP
    #raise "Cannot check for package #{name} on #{self}"
    0
  end

  def install_package(name, cmdline_args = '')
    #HACK NOOP
    #raise "Package #{name} cannot be installed on #{self}"
    0
  end

  def uninstall_package(name, cmdline_args = '')
    #HACK NOOP
    #raise "Package #{name} cannot be uninstalled on #{self}"
    0
  end

  private

  # @api private
  def identify_windows_architecture
    arch = nil
    execute("wmic os get osarchitecture",
    :acceptable_exit_codes => (0...127)) do |result|

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
    execute("wmic os get name",
    :acceptable_exit_codes => (0...127)) do |result|
      arch = result.stdout =~ /64/ ? '64' : '32'
    end
    arch
  end
end
