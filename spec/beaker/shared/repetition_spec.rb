require 'spec_helper'

module Beaker
  module Shared
    describe Repetition do

      context 'repeat_for' do
        it "repeats a block for 5 seconds" do
          allow( Time ).to receive( :now ).and_return( 0, 1, 2, 3, 4, 5, 6 )

          block = double( 'block' )
          expect( block ).to receive( :exec ).exactly( 5 ).times.and_return( false )
          
          subject.repeat_for( 5 ) do
            block.exec
          end
        end

        it "should short circuit if the block is complete" do
          allow( Time ).to receive( :now ).and_return( 0, 1, 2, 3, 4, 5 )

          block = double( 'block' )
          expect( block ).to receive( :exec ).once.and_return( true )
          
          subject.repeat_for( 5 ) do
            block.exec
          end

        end

      end

      context 'repeat_fibonacci_style_for' do
        it "sleeps in fibonacci increasing intervals" do

          block = double( 'block' )
          expect( block ).to receive( :exec ).exactly( 5 ).times.and_return( false )
          allow( subject ).to receive( 'sleep' ).and_return( true )
          expect( subject ).to receive( :sleep ).with( 1 ).exactly( 2 ).times
          expect( subject ).to receive( :sleep ).with( 2 ).once
          expect( subject ).to receive( :sleep ).with( 3 ).once
          expect( subject ).to receive( :sleep ).with( 5 ).once
          expect( subject ).to receive( :sleep ).with( 8 ).never

          subject.repeat_fibonacci_style_for( 5 ) do
            block.exec
          end

        end

        it "should short circuit if the block is complete" do

          block = double( 'block' )
          expect( block ).to receive( :exec ).once.and_return( true )
          allow( subject ).to receive( 'sleep' ).and_return( true )
          expect( subject ).to receive( :sleep ).with( 1 ).once
          expect( subject ).to receive( :sleep ).with( 2 ).never
          expect( subject ).to receive( :sleep ).with( 3 ).never
          expect( subject ).to receive( :sleep ).with( 5 ).never
          expect( subject ).to receive( :sleep ).with( 8 ).never

          subject.repeat_fibonacci_style_for( 5 ) do
            block.exec
          end

        end
      end

    end

  end
end
