require 'spec_helper'

class ClassMixedWithDSLOutcomes
  include PuppetAcceptance::DSL::Outcomes
end

describe ClassMixedWithDSLOutcomes do
  let(:logger) { double }
  before { subject.stub( :logger ).and_return( logger ) }

  describe '#pass_test' do
    it "logs the notification passed to it and raises PassTest" do
      logger.should_receive( :notify ).with( /blah/ )
      expect { subject.pass_test('blah') }.
        to raise_error PuppetAcceptance::DSL::Outcomes::PassTest
    end
  end

  describe '#skip_test' do
    it "logs the notification passed to it and raises SkipTest" do
      logger.should_receive( :notify ).with( /blah/ )
      expect { subject.skip_test('blah') }.
        to raise_error PuppetAcceptance::DSL::Outcomes::SkipTest
    end
  end

  describe '#pending_test' do
    it "logs the notification passed to it and raises PendingTest" do
      logger.should_receive( :warn ).with( /blah/ )
      expect { subject.pending_test('blah') }.
        to raise_error PuppetAcceptance::DSL::Outcomes::PendingTest
    end
  end

  describe '#fail_test' do
    it "logs the notification passed to it and raises FailTest" do
      logger.should_receive( :warn )
      logger.should_receive( :pretty_backtrace )
      expect { subject.fail_test('blah') }.
        to raise_error PuppetAcceptance::DSL::Outcomes::FailTest
    end
  end
end
