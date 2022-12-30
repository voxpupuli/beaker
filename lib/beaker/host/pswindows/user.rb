module PSWindows::User
  include Beaker::CommandFactory

  def user_list()
    execute('cmd /c echo "" | wmic useraccount where localaccount="true" get name /format:value') do |result|
      users = []
      result.stdout.each_line do |line|
        users << (line.match(/^Name=(.+)/) or next)[1]
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

  def user_present(name, &block)
    execute("net user /add \"#{name}\"", {:acceptable_exit_codes => [0,2]}, &block)
  end

  def user_absent(name, &block)
    execute("net user /delete \"#{name}\"", {:acceptable_exit_codes => [0,2]}, &block)
  end
end
