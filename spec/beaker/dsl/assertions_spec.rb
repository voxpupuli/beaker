require 'spec_helper'

class ClassMixedWithDSLAssertions
  include Beaker::DSL::Assertions
end

describe ClassMixedWithDSLAssertions do
  describe '#assert_output' do
    it 'defaults to checking stdout' do
      stdout = <<CONSOLE
This should not have space infront of it
  While this should have two spaces infront of it
    And this 3, all lines should be to stdout
CONSOLE

      expectation = <<CONSOLE
        This should not have space infront of it
          While this should have two spaces infront of it
            And this 3, all lines should be to stdout
CONSOLE

      result = double
      expect( result ).to receive( :nil? ).at_least( :once ).and_return( false )
      expect( result ).to receive( :stdout ).and_return( stdout )
      expect( result ).to receive( :output ).and_return( stdout )
      expect( result ).to receive( :stderr ).and_return( '' )

      expect( subject ).to receive( :result ).at_least( :once ).and_return( result )
      expect { subject.assert_output expectation }.to_not raise_error
    end

    it 'allows specifying stream markers' do
      output = <<OUTPUT
This is on stdout
While this is on stderr
And THIS is again on stdout
OUTPUT

      stdout = <<STDOUT
This is on stdout
And THIS is again on stdout
STDOUT

      stderr = <<STDERR
While this is on stderr
STDERR

      expectation = <<EXPECT
        STDOUT> This is on stdout
        STDERR> While this is on stderr
        STDOUT> And THIS is again on stdout
EXPECT

      result = double
      expect( result ).to receive( :nil? ).at_least( :once ).and_return( false )
      expect( result ).to receive( :stdout ).and_return( stdout )
      expect( result ).to receive( :output ).and_return( output )
      expect( result ).to receive( :stderr ).and_return( stderr )

      expect( subject ).to receive( :result ).at_least( :once ).and_return( result )
      expect { subject.assert_output expectation }.to_not raise_error
    end

    it 'raises an approriate error when output does not match expectations' do
      FakeFS.without do
        output = <<OUTPUT
This is on stdout
Holy Crap, what HAPPENED!?!?!?
And THIS is again on stdout
OUTPUT

        stdout = <<STDOUT
This is on stdout
And THIS is again on stdout
STDOUT

        stderr = <<STDERR
Holy Crap, what HAPPENED!?!?!?
STDERR

        expectation = <<EXPECT
        STDOUT> This is on stdout
        STDERR> While this is on stderr
        STDOUT> And THIS is again on stdout
EXPECT
        result = double
        expect( result ).to receive( :nil? ).at_least( :once ).and_return( false )
        expect( result ).to receive( :output ).and_return( output )

        expect( subject ).to receive( :result ).at_least( :once ).and_return( result )
        expect { subject.assert_output expectation }.to raise_error( MiniTest::Assertion )
      end
    end
  end
end
