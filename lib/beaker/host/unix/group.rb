module Unix::Group
  include Beaker::CommandFactory

  def group_list(&block)
    execute("getent group") do |result|
      groups = []
      result.stdout.each_line do |line|
        groups << (line.match(/^([^:]+)/) or next)[1]
      end

      yield result if block_given?

      groups
    end
  end

  def group_get(name, &block)
    execute("getent group #{name}") do |result|
      fail_test "failed to get group #{name}" unless result.stdout =~ /^#{name}:.*:[0-9]+:/

      yield result if block_given?
    end
  end

  def group_gid(name)
    execute("getent group #{name}") do |result|
      # Format is:
      # wheel:x:10:root
      result.stdout.split(':')[2]
    end
  end

  def group_present(name, &block)
    execute("if ! getent group #{name}; then groupadd #{name}; fi", {}, &block)
  end

  def group_absent(name, &block)
    execute("if getent group #{name}; then groupdel #{name}; fi", {}, &block)
  end
end
