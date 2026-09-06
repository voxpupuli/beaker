module PSWindows::User
  include Beaker::CommandFactory

  def user_list
    execute('powershell.exe -NoProfile -NonInteractive -Command "Get-CimInstance Win32_UserAccount -Filter \'LocalAccount=True\' | Select-Object -ExpandProperty Name"') do |result|
      users = []
      result.stdout.each_line do |line|
        user = line.strip
        next if user.empty?

        users << user
      end

      yield result if block_given?

      users
    end
  end

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
