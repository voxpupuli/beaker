module CommandFactory
  include Test::Unit::Assertions

  def execute(command, options={}, &block)
    command = Command.new(command)

    result = command.exec(self, options)

    if block_given?
      yield result
    else
      result.stdout.chomp
    end
  end

  def fail_test(msg)
    assert(false, msg)
  end
end
