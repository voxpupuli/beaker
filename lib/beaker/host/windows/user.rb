module Windows::User
  include Beaker::CommandFactory

  # using powershell commands as wmic is deprecated in windows 2025
  def user_list_using_powershell
    execute('cmd /c echo "" | powershell.exe "Get-LocalUser | Select-Object -ExpandProperty Name"') do |result|
      users = []
      result.stdout.each_line do |line|
        name = line.strip
        users << name unless name.empty?
      end

      yield result if block_given?

      users
    end
  end

  alias user_list user_list_using_powershell

  def user_get(name)
    execute("net user \"#{name}\"") do |result|
      fail_test "failed to get user #{name}" if result.exit_code != 0

      yield result if block_given?
      result
    end
  end

  def user_present(name, &)
    execute("net user /add \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end

  def user_absent(name, &)
    execute("net user /delete \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end
end
