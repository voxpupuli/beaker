require 'spec_helper'

module Beaker
  module Shared
    describe Repetition do

      context 'repeat_for' do
        it "repeats a block for 5 seconds" do
          Time.stub( :now ).and_return( 0, 1, 2, 3, 4, 5, 6 )

          block = mock( 'block' )
          block.should_receive( :exec ).exactly( 5 ).times.and_return( false )
          
          subject.repeat_for( 5 ) do
            block.exec
          end
        end

        it "should short circuit if the block is complete" do
          Time.stub( :now ).and_return( 0, 1, 2, 3, 4, 5 )

          block = mock( 'block' )
          block.should_receive( :exec ).exactly( 1 ).times.and_return( true )
          
          subject.repeat_for( 5 ) do
            block.exec
          end

        end

      end

      context 'repeat_fibonacci_style_for' do
        it "sleeps in fibonacci increasing intervals" do

          block = mock( 'block' )
          block.should_receive( :exec ).exactly( 5 ).times.and_return( false )
          subject.stub( 'sleep' ).and_return( true )
          subject.should_receive( :sleep ).with( 1 ).exactly( 2 ).times
          subject.should_receive( :sleep ).with( 2 ).exactly( 1 ).times
          subject.should_receive( :sleep ).with( 3 ).exactly( 1 ).times
          subject.should_receive( :sleep ).with( 5 ).exactly( 1 ).times
          subject.should_receive( :sleep ).with( 8 ).exactly( 0 ).times

          subject.repeat_fibonacci_style_for( 5 ) do
            block.exec
          end

        end

        it "should short circuit if the block is complete" do

          block = mock( 'block' )
          block.should_receive( :exec ).exactly( 1 ).times.and_return( true )
          subject.stub( 'sleep' ).and_return( true )
          subject.should_receive( :sleep ).with( 1 ).exactly( 1 ).times
          subject.should_receive( :sleep ).with( 2 ).exactly( 0 ).times
          subject.should_receive( :sleep ).with( 3 ).exactly( 0 ).times
          subject.should_receive( :sleep ).with( 5 ).exactly( 0 ).times
          subject.should_receive( :sleep ).with( 8 ).exactly( 0 ).times

          subject.repeat_fibonacci_style_for( 5 ) do
            block.exec
          end

        end
      end

    end

  end
end
