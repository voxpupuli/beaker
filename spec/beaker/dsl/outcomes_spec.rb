require 'spec_helper'

class ClassMixedWithDSLOutcomes
  include Beaker::DSL::Outcomes
end

describe ClassMixedWithDSLOutcomes do
  let(:logger) { double }
  before { allow( subject ).to receive( :logger ).and_return( logger ) }

  describe '#pass_test' do
    it "logs the notification passed to it and raises PassTest" do
      expect( logger ).to receive( :notify ).with( /blah/ )
      expect { subject.pass_test('blah') }.
        to raise_error Beaker::DSL::Outcomes::PassTest
    end
  end

  describe '#skip_test' do
    it "logs the notification passed to it and raises SkipTest" do
      expect( logger ).to receive( :notify ).with( /blah/ )
      expect { subject.skip_test('blah') }.
        to raise_error Beaker::DSL::Outcomes::SkipTest
    end
  end

  describe '#pending_test' do
    it "logs the notification passed to it and raises PendingTest" do
      expect( logger ).to receive( :warn ).with( /blah/ )
      expect { subject.pending_test('blah') }.
        to raise_error Beaker::DSL::Outcomes::PendingTest
    end
  end

  describe '#fail_test' do
    it "logs the notification passed to it and raises FailTest" do
      expect( logger ).to receive( :warn )
      expect( logger ).to receive( :pretty_backtrace )
      expect { subject.fail_test('blah') }.
        to raise_error Beaker::DSL::Outcomes::FailTest
    end
  end
end
