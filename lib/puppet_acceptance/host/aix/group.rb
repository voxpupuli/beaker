module Aix::Group
  include PuppetAcceptance::CommandFactory

  def group_list(&block)
    execute("lsgroup ALL") do |result|
      groups = []
      result.stdout.each_line do |line|
        groups << (line.match(/^([^:]+)/) or next)[1]
      end

      yield result if block_given?

      groups
    end
  end

  def group_get(name, &block)
    execute("lsgroup #{name}") do |result|
      fail_test "failed to get group #{name}" unless result.stdout =~ /^#{name} id/

      yield result if block_given?
    end
  end

  def group_present(name, &block)
    execute("if ! lsgroup #{name}; then mkgroup #{name}; fi", {}, &block)
  end

  def group_absent(name, &block)
    execute("if lsgroup #{name}; then rmgroup #{name}; fi", {}, &block)
  end
end
