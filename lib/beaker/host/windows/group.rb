module Windows::Group
  include Beaker::CommandFactory

  def group_list()
    execute('cmd /c echo "" | wmic group where localaccount="true" get name /format:value') do |result|
      groups = []
      result.stdout.each_line do |line|
        groups << (line.match(/^Name=(.+)$/) or next)[1]
      end

      yield result if block_given?

      groups
    end
  end

  def group_get(name)
    execute("net localgroup \"#{name}\"") do |result|
      fail_test "failed to get group #{name}" if result.exit_code != 0

      yield result if block_given?
      result
    end
  end

  def group_gid(_name)
    raise NotImplementedError, "Can't retrieve group gid on a Windows host"
  end

  def group_present(name, &block)
    execute("net localgroup /add \"#{name}\"", {:acceptable_exit_codes => [0,2]}, &block)
  end

  def group_absent(name, &block)
    execute("net localgroup /delete \"#{name}\"", {:acceptable_exit_codes => [0,2]}, &block)
  end
end
