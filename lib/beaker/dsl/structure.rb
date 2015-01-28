require 'beaker/dsl/assertions'
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
    #
    #       step 'Expect this to fail' do
    #         expect_failure('expected to fail due to PE-1234') do
    #         assert_equal(400, response.code, 'bad response code from API call')
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
      # @api dsl
      def teardown &block
        @teardown_procs << block
      end

      # Wrap an assert that is supposed to fail due to a product bug, an
      # undelivered feature, or some similar situation.
      #
      # This converts failing asserts into passing asserts (so we can continue to
      # run the test even though there are underlying product bugs), and converts
      # passing asserts into failing asserts (so we know when the underlying product
      # bug has been fixed).
      #
      # Pass an assert as a code block, and pass an explanatory message as a
      # parameter. The assert's logic will be inverted (so passes turn into fails
      # and fails turn into passes).
      #
      # @example Typical usage
      #   expect_failure('expected to fail due to PE-1234') do
      #     assert_equal(400, response.code, 'bad response code from API call')
      #   end
      #
      # @example Output when a product bug would normally cause the assert to fail
      #   Warning: An assertion was expected to fail, and did.
      #   This is probably due to a known product bug, and is probably not a problem.
      #   Additional info: 'expected to fail due to PE-6995'
      #   Failed assertion: 'bad response code from API call.
      #   <400> expected but was <409>.'
      #
      # @example Output when the product bug has been fixed
      #   <RuntimeError: An assertion was expected to fail, but passed.
      #   This is probably because a product bug was fixed, and "expect_failure()"
      #   needs to be removed from this assert.
      #   Additional info: 'expected to fail due to PE-6996'>
      #
      # @param [String] explanation A description of why this assert is expected to
      #                             fail
      # @param block [Proc] block of code is expected to either raise an
      #                     {Beaker::Assertions} or else return a value that
      #                     will be ignored
      # @raise [RuntimeError] if the code block passed to this method does not raise
      #                       a {Beaker::Assertions} (i.e., if the assert
      #                       passes)
      # @author Chris Cowell-Shah (<tt>ccs@puppetlabs.com</tt>)
      # @api dsl
      def expect_failure(explanation, &block)
        begin
          yield if block_given?  # code block should contain an assert that you expect to fail
        rescue Beaker::DSL::Assertions, Minitest::Assertion => failed_assertion
          # Yay! The assert in the code block failed, as expected.
          # Swallow the failure so the test passes.
          logger.notify 'An assertion was expected to fail, and did. ' +
                          'This is probably due to a known product bug, ' +
                          'and is probably not a problem. ' +
                          "Additional info: '#{explanation}' " +
                          "Failed assertion: '#{failed_assertion}'"
          return
        end
        # Uh-oh! The assert in the code block unexpectedly passed.
        fail('An assertion was expected to fail, but passed. ' +
                 'This is probably because a product bug was fixed, and ' +
                 '"expect_failure()" needs to be removed from this test. ' +
                 "Additional info: '#{explanation}'")
      end
    end
  end
end
