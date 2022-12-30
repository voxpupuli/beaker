module Aix::Group
  include Beaker::CommandFactory

  def group_list()
    execute("lsgroup -a ALL") do |result|
      yield result if block_given?

      result.stdout.lines.map(&:strip)
    end
  end

  def group_get(name)
    execute("lsgroup #{name}") do |result|
      fail_test "failed to get group #{name}" unless /^#{name} id/.match?(result.stdout)

      yield result if block_given?
      result
    end
  end

  def group_gid(name)
    execute("lsgroup -a id #{name}") do |result|
      # Format is:
      # staff id=500
      result.stdout.split('=').last.strip
    end
  end

  def group_present(name, &block)
    execute("if ! lsgroup #{name}; then mkgroup #{name}; fi", {}, &block)
  end

  def group_absent(name, &block)
    execute("if lsgroup #{name}; then rmgroup #{name}; fi", {}, &block)
  end
end
