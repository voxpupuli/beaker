module Unix::User
  include Beaker::CommandFactory

  def user_list()
    execute("getent passwd") do |result|
      users = []
      result.stdout.each_line do |line|
        users << (line.match( /^([^:]+)/) or next)[1]
      end

      yield result if block_given?

      users
    end
  end

  def user_get(name)
    execute("getent passwd #{name}") do |result|
      fail_test "failed to get user #{name}" unless /^#{name}:/.match?(result.stdout)

      yield result if block_given?
      result
    end
  end

  def user_present(name, &block)
    execute("if ! getent passwd #{name}; then useradd #{name}; fi", {}, &block)
  end

  def user_absent(name, &block)
    execute("if getent passwd #{name}; then userdel #{name}; fi", {}, &block)
  end
end
