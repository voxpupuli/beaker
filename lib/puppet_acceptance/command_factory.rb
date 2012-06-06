module PuppetAcceptance
  module CommandFactory
    include Test::Unit::Assertions

    def execute(command, options={}, &block)
      result = self.exec(Command.new(command), options)

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
end
