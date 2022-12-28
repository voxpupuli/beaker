require 'spec_helper'

module Beaker
  module Shared
    describe Repetition do

      describe '#repeat_for' do
        it "repeats a block for 5 seconds" do
          allow( Time ).to receive( :now ).and_return( 0, 1, 2, 3, 4, 5, 6 )

          block = double( 'block' )
          expect( block ).to receive( :exec ).exactly( 5 ).times.and_return( false )

          subject.repeat_for( 5 ) do
            block.exec
          end
        end

        it "shorts circuit if the block is complete" do
          allow( Time ).to receive( :now ).and_return( 0, 1, 2, 3, 4, 5 )

          block = double( 'block' )
          expect( block ).to receive( :exec ).once.and_return( true )

          subject.repeat_for( 5 ) do
            block.exec
          end

        end

      end

      describe '#repeat_fibonacci_style_for' do
        let(:block) { double("block") }

        it "sleeps in fibonacci increasing intervals" do
          expect( block ).to receive( :exec ).exactly( 5 ).times.and_return( false )
          allow( subject ).to receive( 'sleep' ).and_return( true )

          expect( subject ).to receive( :sleep ).with( 1 ).twice
          expect( subject ).to receive( :sleep ).with( 2 ).once
          expect( subject ).to receive( :sleep ).with( 3 ).once
          expect( subject ).to receive( :sleep ).with( 5 ).once
          expect( subject ).not_to receive( :sleep ).with( 8 )

          subject.repeat_fibonacci_style_for( 5 ) do
            block.exec
          end
        end

        it "shorts circuit if the block succeeds (returns true)" do
          expect(block).to receive(:exec).and_return(false).ordered.exactly(4).times
          expect(block).to receive(:exec).and_return( true).ordered.once

          expect(subject).to receive(:sleep).with(1).twice
          expect(subject).to receive(:sleep).with(2).once
          expect(subject).to receive(:sleep).with(3).once
          expect(subject).not_to receive(:sleep).with(anything)

          subject.repeat_fibonacci_style_for(20) do
            block.exec
          end
        end

        it "returns false if block never returns that it is done (true)" do
          expect(block).to receive(:abcd).exactly(3).times.and_return(false)

          expect(subject).to receive(:sleep).with(1).twice
          expect(subject).to receive(:sleep).with(2).once
          expect(subject).not_to receive(:sleep).with(anything)

          success_result = subject.repeat_fibonacci_style_for(3) do
            block.abcd
          end
          expect(success_result).to be false
        end

        it "never sleeps if block is successful right at first (returns true)" do
          expect(block).to receive(:fake01).once.and_return(true)

          expect(subject).not_to receive(:sleep)

          subject.repeat_fibonacci_style_for(3) do
            block.fake01
          end
        end


      end

    end

  end
end
