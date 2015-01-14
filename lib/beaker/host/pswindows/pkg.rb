module PSWindows::Pkg
  include Beaker::CommandFactory

  def check_for_command(name)
    result = exec(Beaker::Command.new("where #{name}"), :acceptable_exit_codes => (0...127))
    result.exit_code == 0
  end

  def check_for_package(name)
    raise "Cannot check for package #{name} on #{self}"
  end

  def install_package(name, cmdline_args = '')
    raise "Package #{name} cannot be installed on #{self}"
  end

  def uninstall_package(name, cmdline_args = '')
    raise "Package #{name} cannot be uninstalled on #{self}"
  end

  private

  # @api private
  def identify_windows_architecture
    arch = nil
    execute("echo '' | wmic os get osarchitecture",
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
    execute("echo '' | wmic os get name | grep x64",
            :acceptable_exit_codes => (0...127)) do |result|
      arch = result.exit_code == 0 ? '64' : '32'
    end
    arch
  end
end
