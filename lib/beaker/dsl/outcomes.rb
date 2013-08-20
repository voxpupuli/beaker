module Beaker
  module DSL
    # This module includes dsl helpers for setting the state of a test case.
    # They do not need inclusion if using third party test runner. The
    # Exception classes that they raise however should be defined as other
    # DSL helpers will raise them as needed. See individual DSL modules
    # for their specific dependencies. A class that mixes in this module
    # must have a method #logger which will yield an object that responds to
    # #notify and #warn. NOTE: the interface to logger may change shortly and
    # {Beaker::Logger} should be consulted for the appropriate
    # interface.
    #
    # Simply these methods log a message and raise the appropriate Exception
    # The exceptions are are caught by {Beaker::TestCase} and are
    # designed to allow some degree of freedom from the individual third
    # party test runners that could be used.
    module Outcomes

      # Raise this class if it is determined that a test case should not
      # be executed because the feature in question is still a
      # "Work in Progress"
      class PendingTest < Exception; end

      # Raise this class if execution should be stopped because the test
      # is not applicable within a given environment.
      class SkipTest    < Exception; end

      # Raise this class if some criteria has been met that proves a failure.
      class FailTest    < Exception; end

      # Raise this class if execution should stop because enough criteria has
      # shown itself to pass the test.
      class PassTest    < Exception; end


      # Raises FailTest Exception and logs an error message
      #
      # @param [String] msg An optional message to log
      # @raise [FailTest]
      # @api dsl
      def fail_test msg = nil
        message = formatted_message( msg, 'Failed' )
        logger.warn( [message, logger.pretty_backtrace].join("\n") )

        raise( FailTest, message )
      end

      # Raises PassTest Exception and logs a message
      #
      # @param [String] msg An optional message to log
      # @raise [PassTest]
      # @api dsl
      def pass_test msg = nil
        message = formatted_message( msg, 'Passed' )
        logger.notify( message )

        raise( PassTest, message )
      end

      # Raises PendingTest Exception and logs an error message
      #
      # @param [String] msg An optional message to log
      # @raise [PendingTest]
      # @api dsl
      def pending_test msg = nil
        message = formatted_message( msg, 'is Pending' )
        logger.warn( message )

        raise( PendingTest, message )
      end

      # Raises SkipTest Exception and logs a message
      #
      # @param [String] msg An optional message to log
      # @raise [SkipTest]
      # @api dsl
      def skip_test msg = nil
        message = formatted_message( msg, 'was Skipped' )
        logger.notify( message )

        raise( SkipTest, message )
      end

      # Formats an optional message or self appended by a state, either
      # bracketted in newlines
      #
      # @param [String, nil] message The message (or nil) to format
      # @param [String] default_str  The string to be appended to self if
      #                              message is nil
      #
      # @return [String] A prettier string with helpful info
      # @!visibility private
      def formatted_message(message, default_str )
        msg = message ? "\n#{message}\n" : "\n#{self} #{default_str}.\n"
        return msg
      end
    end
  end
end
