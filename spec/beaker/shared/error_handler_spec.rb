require 'spec_helper'

module Beaker
  module Shared
    describe ErrorHandler do

      let( :backtrace ) { "I'm the backtrace\nYes I am!\nI have important information" }
      let( :logger )    { double( 'logger' ) }

      before :each do
        allow( logger ).to receive( :error ).and_return( true )
        allow( logger ).to receive( :pretty_backtrace ).and_return( backtrace )

      end

      context 'report_and_raise' do

        it "records the backtrace of the exception to the logger" do
          ex = Exception.new("ArgumentError")
          allow( ex ).to receive( :backtrace ).and_return(backtrace)
          mesg = "I'm the extra message"
         
          backtrace.each_line do |line|
            expect( logger ).to receive( :error ).with(line)
          end

          expect( subject ).to receive( :raise ).once

          subject.report_and_raise(logger, ex, mesg) 

        end



      end

    end

  end
end
