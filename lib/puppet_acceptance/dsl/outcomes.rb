module PuppetAcceptance
  module DSL

    # Module to ...
    module Outcomes

      class PendingTest < Exception; end
      class SkipTest    < Exception; end
      class FailTest    < Exception; end
      class PassTest    < Exception; end

      def pass_test msg
        logger.notify( "\n#{msg}\n" )
        raise( PassTest, msg )
      end

      def skip_test msg
        logger.notify( "Skip: #{msg}\n" )
        raise( SkipTest, msg )
      end

      def fail_test msg
        logger.warn( [msg, logger.pretty_backtrace].join("\n") )
        raise( FailTest, msg )
      end

      def pending_test msg = "WIP"
        logger.warn( msg )
        raise( PendingTest, msg )
      end

    end
  end
end
