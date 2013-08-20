module Beaker
  module DSL
    # These are simple structural elements necessary for writing
    # understandable tests and ensuring cleanup actions happen. If using a
    # third party test runner they are unnecessary.
    #
    # To include this in your own test runner a method #logger should be
    # available to yield a logger that implements
    # {Beaker::Logger}'s interface. As well as a method
    # #teardown_procs that yields an array.
    #
    # @example Structuring a test case.
    #     test_name 'Look at me testing things!' do
    #       teardown do
    #         ...clean up actions...
    #       end
    #
    #       step 'Prepare the things' do
    #         ...setup steps...
    #       end
    #
    #       step 'Test the things' do
    #         ...tests...
    #       end
    #     end
    #
    module Structure

      # Provides a method to help structure tests into coherent steps.
      # @param [String] step_name The name of the step to be logged.
      # @param [Proc] block The actions to be performed in this step.
      # @api dsl
      def step step_name, &block
        logger.notify "\n  * #{step_name}\n"
        yield if block_given?
      end

      # Provides a method to name tests.
      #
      # @param [String] my_name The name of the test to be logged.
      # @param [Proc] block The actions to be performed during this test.
      #
      # @api dsl
      def test_name my_name, &block
        logger.notify "\n#{my_name}\n"
        yield if block_given?
      end

      # Declare a teardown process that will be called after a test case is
      # complete.
      #
      # @param block [Proc] block of code to execute during teardown
      # @example Always remove /etc/puppet/modules
      #   teardown do
      #     on(master, puppet_resource('file', '/etc/puppet/modules',
      #       'ensure=absent', 'purge=true'))
      #   end
      def teardown &block
        @teardown_procs << block
      end
    end
  end
end
