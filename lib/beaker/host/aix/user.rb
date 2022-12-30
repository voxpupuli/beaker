module Aix::User
  include Beaker::CommandFactory

  def user_list()
    execute("lsuser ALL") do |result|
      users = []
      result.stdout.each_line do |line|
        users << line.split(' ')[0]
      end

      yield result if block_given?

      users
    end
  end

  def user_get(name)
    execute("lsuser #{name}") do |result|
      fail_test "failed to get user #{name}" unless /^#{name} id/.match?(result.stdout)

      yield result if block_given?
      result
    end
  end

  def user_present(name, &block)
    execute("if ! lsuser #{name}; then mkuser #{name}; fi", {}, &block)
  end

  def user_absent(name, &block)
    execute("if lsuser #{name}; then rmuser #{name}; fi", {}, &block)
  end
end
