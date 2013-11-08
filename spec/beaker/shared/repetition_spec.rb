require 'spec_helper'

module Beaker
  module Shared
    describe Repetition do

      context 'repeat_for' do
        it "repeats a block for 5 seconds" do
          Time.stub( :now ).and_return( 0, 1, 2, 3, 4, 5, 6 )

          block = double( 'block' )
          block.should_receive( :exec ).exactly( 5 ).times.and_return( false )
          
          subject.repeat_for( 5 ) do
            block.exec
          end
        end

        it "should short circuit if the block is complete" do
          Time.stub( :now ).and_return( 0, 1, 2, 3, 4, 5 )

          block = double( 'block' )
          block.should_receive( :exec ).once.and_return( true )
          
          subject.repeat_for( 5 ) do
            block.exec
          end

        end

      end

      context 'repeat_fibonacci_style_for' do
        it "sleeps in fibonacci increasing intervals" do

          block = double( 'block' )
          block.should_receive( :exec ).exactly( 5 ).times.and_return( false )
          subject.stub( 'sleep' ).and_return( true )
          subject.should_receive( :sleep ).with( 1 ).exactly( 2 ).times
          subject.should_receive( :sleep ).with( 2 ).once
          subject.should_receive( :sleep ).with( 3 ).once
          subject.should_receive( :sleep ).with( 5 ).once
          subject.should_receive( :sleep ).with( 8 ).never

          subject.repeat_fibonacci_style_for( 5 ) do
            block.exec
          end

        end

        it "should short circuit if the block is complete" do

          block = double( 'block' )
          block.should_receive( :exec ).once.and_return( true )
          subject.stub( 'sleep' ).and_return( true )
          subject.should_receive( :sleep ).with( 1 ).once
          subject.should_receive( :sleep ).with( 2 ).never
          subject.should_receive( :sleep ).with( 3 ).never
          subject.should_receive( :sleep ).with( 5 ).never
          subject.should_receive( :sleep ).with( 8 ).never

          subject.repeat_fibonacci_style_for( 5 ) do
            block.exec
          end

        end
      end

    end

  end
end
