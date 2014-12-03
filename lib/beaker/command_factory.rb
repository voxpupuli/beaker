require 'minitest/test'

module Beaker
  module CommandFactory
    include Minitest::Assertions
    #Why do we need this accessor?
    # https://github.com/seattlerb/minitest/blob/master/lib/minitest/assertions.rb#L8-L12
    # Protocol: Nearly everything here boils up to +assert+, which
    # expects to be able to increment an instance accessor named
    # +assertions+. This is not provided by Assertions and must be
    # provided by the thing including Assertions. See Minitest::Runnable
    # for an example.
    attr_accessor :assertions
    def assertions
      @assertions || 0
    end

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
