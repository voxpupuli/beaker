require 'spec_helper'

module Beaker
  module Shared
    describe ErrorHandler do

      let( :backtrace ) { "I'm the backtrace\nYes I am!\nI have important information" }
      let( :logger )    { mock( 'logger' ) }

      before :each do
        logger.stub( :error ).and_return( true )
        logger.stub( :pretty_backtrace ).and_return( backtrace )

      end

      context 'report_and_raise' do

        it "records the backtrace of the exception to the logger" do
          ex = Exception.new("ArgumentError")
          ex.stub( :backtrace ).and_return(backtrace)
          mesg = "I'm the extra message"
         
          backtrace.each_line do |line|
            logger.should_receive( :error ).with(line)
          end

          subject.should_receive( :raise ).once

          subject.report_and_raise(logger, ex, mesg) 

        end



      end

    end

  end
end
