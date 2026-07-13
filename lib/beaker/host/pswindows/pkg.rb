module PSWindows::Pkg
  include Beaker::CommandFactory

  def check_for_command(name)
    result = exec(Beaker::Command.new("where #{name}"), :accept_all_exit_codes => true)
    result.exit_code == 0
  end

  def check_for_package(_name)
    # HACK: NOOP
    # raise "Cannot check for package #{name} on #{self}"
    0
  end

  def install_package(_name, _cmdline_args = '')
    # HACK: NOOP
    # raise "Package #{name} cannot be installed on #{self}"
    0
  end

  def uninstall_package(_name, _cmdline_args = '')
    # HACK: NOOP
    # raise "Package #{name} cannot be uninstalled on #{self}"
    0
  end

  # Examine the host system to determine the architecture
  # @return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    identify_windows_architecture.include?('AMD64')
  end

  private

  # @api private
  def identify_windows_architecture
    arch = nil
    execute('echo %PROCESSOR_ARCHITECTURE%', :accept_all_exit_codes => true) do |result|
      arch = result.stdout.strip if result.exit_code == 0
    end
    arch
  end
end
