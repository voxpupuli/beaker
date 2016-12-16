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

    # Helper to create & run commands
    #
    # @note {Beaker::Host#exec} gets passed a duplicate of the options hash argument.
    # @note {Beaker::Command#initialize} gets passed selected options from the
    #   options hash argument. Specifically, :prepend_cmds & :cmdexe.
    #
    # @param [String] command Command to run
    # @param [Hash{Symbol=>Boolean, Array<Fixnum>}] options Options to pass
    #   through for command execution
    #
    # @api private
    # @return [String] Stdout from command execution
    def execute(command, options={}, &block)
      cmd_create_options = {}
      exec_opts = options.dup
      cmd_create_options[:prepend_cmds] = exec_opts.delete(:prepend_cmds) || nil
      cmd_create_options[:cmdexe] = exec_opts.delete(:cmdexe) || false
      result = self.exec(Command.new(command, [], cmd_create_options), exec_opts)

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
