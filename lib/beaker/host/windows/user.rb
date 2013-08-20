module Windows::User
  include Beaker::CommandFactory

  def user_list(&block)
    execute('cmd /c echo "" | wmic useraccount where localaccount="true" get name /format:value') do |result|
      users = []
      result.stdout.each_line do |line|
        users << (line.match(/^Name=([\w ]+)/) or next)[1]
      end

      yield result if block_given?

      users
    end
  end

  def user_get(name, &block)
    execute("net user \"#{name}\"") do |result|
      fail_test "failed to get user #{name}" unless result.stdout =~ /^User name\s+#{name}/

      yield result if block_given?
    end
  end

  def user_present(name, &block)
    execute("net user /add \"#{name}\"", {:acceptable_exit_codes => [0,2]}, &block)
  end

  def user_absent(name, &block)
    execute("net user /delete \"#{name}\"", {:acceptable_exit_codes => [0,2]}, &block)
  end
end
